#if !targetEnvironment(macCatalyst)
import SwiftUI
import Combine
import AlarmKit
import ActivityKit
import AppIntents
import AVFoundation
import Speech

struct WakeAlarmMetadata: AlarmMetadata { var alarmID: String }

struct OpenWakeAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "完成唤醒任务"
    static var openAppWhenRun = true
    @Parameter(title: "闹钟编号") var alarmID: String
    init() {}
    init(id: UUID) { alarmID = id.uuidString }
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            try await AlarmController.shared.openSystemAlarm(id)
        }
        return .result()
    }
}

@MainActor
final class AlarmController: ObservableObject {
    static let shared = AlarmController()
    @Published private(set) var archive = AlarmArchive()
    @Published var presented = false
    @Published var error: String?
    @Published private(set) var systemStatus: String?
    @Published private(set) var authorized = false
    @Published private(set) var missingSchedules: Set<UUID> = []
    private var loaded = false
    private var started = false
    private var foreground = false
    private var busy = false
    private var reconciling = false
    private var attemptedSoundMigration = false
    private var scheduleMutations: Set<UUID> = []
    private var nextRetryAttempt = Date.distantPast
    private var retryMutations: Set<UUID> = []
    private var finishingSessions: Set<UUID> = []
    private var updatesTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private let manager = AlarmManager.shared
    private var storeURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LocalWakeAlarms", isDirectory: true).appendingPathComponent("alarms.json")
    }
    var active: WakeSession? { archive.sessions.first { $0.ready } }
    var pendingTests: [WakeSession] { archive.sessions.filter { $0.isTest && $0.finishedAt == nil && $0.scheduledTestAt != nil } }
    var alarms: [LocalAlarm] { archive.alarms.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) } }

    private init() { load() }
    private func load() {
        do {
            if FileManager.default.fileExists(atPath: storeURL.path) {
                let result = try AlarmArchiveMigration.decode(Data(contentsOf: storeURL))
                guard result.archive.version == 1 else { throw WakeError.message("闹钟数据版本不受支持") }
                archive = result.archive
                if result.changed {
                    loaded = true
                    try persist()
                }
            }
            loaded = true
        } catch { loaded = false; self.error = "无法读取本地闹钟，已停止写入以保护数据：" + error.localizedDescription }
    }
    private func persist() throws {
        guard loaded else { throw WakeError.message("本地闹钟未成功载入，请重新打开应用后重试") }
        let directory = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(archive).write(to: storeURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var excluded = directory
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try excluded.setResourceValues(values)
    }
    func start() {
        guard !started else { return }; started = true
        authorized = manager.authorizationState == .authorized
        updatesTask = Task { [weak self] in
            for await alarms in AlarmManager.shared.alarmUpdates {
                guard let self else { return }
                self.authorized = self.manager.authorizationState == .authorized
                guard self.authorized, self.loaded else { continue }
                self.updateMissing(alarms)
                for alarm in alarms where alarm.state == .alerting {
                    do { try await self.acceptAlert(alarm.id) } catch { self.systemStatus = "系统闹钟状态同步失败：" + error.localizedDescription }
                }
            }
        }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if self.foreground { await self.tick() }
            }
        }
    }
    func setForeground(_ value: Bool) {
        foreground = value
        if value {
            start()
            Task { await reconcile(); await tick() }
        }
    }
    func requestAuthorization() async throws {
        let status = try await manager.requestAuthorization()
        authorized = status == .authorized
        guard authorized else { throw WakeError.message("请在系统设置中允许 MikeAgenda 使用闹钟") }
    }
    private func updateMissing(_ system: [AlarmKit.Alarm]) {
        let ids = Set(system.map(\.id))
        missingSchedules = Set(archive.alarms.filter { $0.enabled && !ids.contains($0.id) }.map(\.id))
    }
    func reconcile() async {
        guard !reconciling else { return }
        reconciling = true
        defer { reconciling = false }
        authorized = manager.authorizationState == .authorized
        guard AlarmSystemAccess.canRead(isAuthorized: authorized, storeLoaded: loaded) else {
            missingSchedules = []
            systemStatus = authorized ? "本地闹钟数据尚未载入" : nil
            return
        }
        do {
            for id in archive.removedTaskAlarmIDs ?? [] {
                try cancelIfPresent(id)
                archive.removedTaskAlarmIDs?.removeAll { $0 == id }
                try persist()
            }
            for session in archive.sessions where session.finishedAt == nil && session.endingManually != nil {
                try await finish(sessionID: session.id, manual: session.endingManually!)
            }
            let system = try manager.alarms
            updateMissing(system)
            for alarm in system where alarm.state == .alerting { try await acceptAlert(alarm.id) }
            // Only after a successful authorized read, once per app run. Never retry
            // automatically on each foreground transition or error alert dismissal.
            if !busy && !attemptedSoundMigration && archive.systemSoundVersion != 2 {
                attemptedSoundMigration = true
                try await migrateSystemSounds(system)
            }
            systemStatus = nil
        } catch {
            systemStatus = "系统闹钟同步未完成，本机配置已保留。" + error.localizedDescription
        }
    }
    private func migrateSystemSounds(_ system: [AlarmKit.Alarm]) async throws {
        var deferred = false
        for alarm in system {
            guard alarm.state == .scheduled, let schedule = alarm.schedule else { deferred = true; continue }
            let definition = archive.alarms.first { $0.id == alarm.id }
                ?? archive.sessions.first { $0.retryID == alarm.id && $0.finishedAt == nil }?.alarm
            guard let definition else { continue }
            try await scheduleReplacing(definition, id: alarm.id, scheduleOverride: schedule)
        }
        if !deferred { archive.systemSoundVersion = 2; try persist() }
    }
    func retrySystemSync() async {
        attemptedSoundMigration = false
        await reconcile()
    }
    private func scheduleReplacing(_ definition: LocalAlarm, id: UUID, at date: Date? = nil, scheduleOverride: AlarmKit.Alarm.Schedule? = nil) async throws {
        guard manager.authorizationState == .authorized else { throw WakeError.message("请先允许系统闹钟权限") }
        guard scheduleMutations.insert(id).inserted else { throw WakeError.message("此闹钟正在更新，请稍后重试") }
        defer { scheduleMutations.remove(id) }
        let existing = try manager.alarms.first { $0.id == id }
        guard existing == nil || existing?.state == .scheduled else { throw WakeError.message("请先完成正在响铃的闹钟，再修改它") }
        // Preserve the old time/repeat schedule for rollback, rather than calculating
        // tomorrow's time from the edited definition.
        let previous = existing?.schedule.map { configuration(definition, id: id, scheduleOverride: $0, soundOverride: archive.systemSoundVersion == 2 ? nil : .default) }
        if existing != nil && previous == nil { throw WakeError.message("系统闹钟状态正在变化，请稍后重试") }
        let desired = configuration(definition, id: id, at: date, scheduleOverride: scheduleOverride)
        try await AlarmScheduleWriter.replace(id: id, previous: previous, desired: desired, remove: { id in
            try self.manager.cancel(id: id)
        }, create: { id, config in
            _ = try await self.manager.schedule(id: id, configuration: config)
        })
    }
    private func configuration(_ alarm: LocalAlarm, id: UUID, at date: Date? = nil, scheduleOverride: AlarmKit.Alarm.Schedule? = nil, soundOverride: ActivityKit.AlertConfiguration.AlertSound? = nil) -> AlarmManager.AlarmConfiguration<WakeAlarmMetadata> {
        let schedule: AlarmKit.Alarm.Schedule
        if let scheduleOverride { schedule = scheduleOverride }
        else if let date { schedule = .fixed(date) }
        else {
            let days: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
            let repeats: AlarmKit.Alarm.Schedule.Relative.Recurrence = alarm.weekdays.isEmpty ? .never : .weekly(alarm.weekdays.compactMap { (1...7).contains($0) ? days[$0 - 1] : nil })
            schedule = .relative(.init(time: .init(hour: alarm.hour, minute: alarm.minute), repeats: repeats))
        }
        // Fixed-date retry alarms do not use AlarmKit countdown presentations.
        let alert = AlarmPresentation.Alert(title: "\(alarm.name)", secondaryButton: AlarmButton(text: "完成任务", textColor: .white, systemImageName: "checklist"), secondaryButtonBehavior: .custom)
        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert), metadata: WakeAlarmMetadata(alarmID: id.uuidString), tintColor: .orange)
        return .alarm(schedule: schedule, attributes: attributes, stopIntent: OpenWakeAlarmIntent(id: id), secondaryIntent: OpenWakeAlarmIntent(id: id), sound: soundOverride ?? .named("electronic_alarm.wav"))
    }
    func save(_ alarm: LocalAlarm) async throws {
        guard !busy else { throw WakeError.message("正在更新闹钟，请稍后重试") }
        guard !archive.sessions.contains(where: { $0.alarm.id == alarm.id && !$0.isTest && $0.finishedAt == nil }) else { throw WakeError.message("请先完成或结束这个闹钟的唤醒任务") }
        if let message = alarm.validationError { throw WakeError.message(message) }
        busy = true; defer { busy = false }
        if alarm.enabled {
            try await validateTaskAvailability(alarm.tasks)
            try await requestAuthorization()
        }
        let old = archive
        if let index = archive.alarms.firstIndex(where: { $0.id == alarm.id }) { archive.alarms[index] = alarm }
        else { archive.alarms.append(alarm) }
        do { try persist() } catch { archive = old; throw error }
        do {
            if alarm.enabled { try await scheduleReplacing(alarm, id: alarm.id) }
            else { try cancelIfPresent(alarm.id) }
            archive.removedTaskAlarmIDs?.removeAll { $0 == alarm.id }
            try persist()
        } catch {
            // Only revert this definition; other alarm sessions may change while schedule awaits.
            archive.alarms.removeAll { $0.id == alarm.id }
            if let previous = old.alarms.first(where: { $0.id == alarm.id }) { archive.alarms.append(previous) }
            try? persist()
            throw error
        }
        await reconcile()
    }
    private func validateTaskAvailability(_ tasks: [WakeTaskConfiguration]) async throws {
        if tasks.contains(where: { $0.kind == .qr || $0.kind == .scene }) {
            guard UIImagePickerController.isSourceTypeAvailable(.camera), await AVCaptureDevice.requestAccess(for: .video) else {
                throw WakeError.message("拍照/二维码任务需要可用的相机及相机授权")
            }
        }
        let phrases = tasks.filter { $0.kind == .phrase }
        if !phrases.isEmpty {
            let authorization = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
            }
            guard authorization == .authorized, await AVAudioApplication.requestRecordPermission() else {
                throw WakeError.message("句子任务需要麦克风及语音识别授权")
            }
            for task in phrases {
                guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: task.locale)), recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
                    throw WakeError.message("此设备暂不支持所选语言的本地识别，请先使用任务测试或选择其他任务")
                }
            }
        }
    }
    func delete(_ alarm: LocalAlarm) async throws {
        guard !busy else { throw WakeError.message("正在更新闹钟，请稍后重试") }
        guard !archive.sessions.contains(where: { $0.alarm.id == alarm.id && !$0.isTest && $0.finishedAt == nil }) else { throw WakeError.message("请先结束正在执行的闹钟") }
        try cancelIfPresent(alarm.id)
        let old = archive
        archive.alarms.removeAll { $0.id == alarm.id }
        do { try persist() } catch { archive = old; throw error }
        await reconcile()
    }
    private func cancelIfPresent(_ id: UUID) throws {
        if try manager.alarms.contains(where: { $0.id == id }) { try manager.cancel(id: id) }
    }
    private func acceptAlert(_ id: UUID) async throws {
        // AsyncSequence values can be stale after cancel/stop. Re-read before creating a session.
        guard try manager.alarms.contains(where: { $0.id == id && $0.state == .alerting }) else { return }
        if let index = archive.sessions.firstIndex(where: { $0.finishedAt == nil && $0.retryID == id }) {
            archive.sessions[index].scheduledTestAt = nil
            archive.sessions[index].quietUntil = nil
            try persist()
            if foreground { presented = true }
            return
        }
        guard let alarm = archive.alarms.first(where: { $0.id == id }) else { return }
        if !archive.sessions.contains(where: { $0.alarm.id == id && !$0.isTest && $0.finishedAt == nil }) {
            archive.sessions.append(WakeSession(alarm: alarm))
            try persist()
        }
        if foreground { presented = true }
    }
    func openSystemAlarm(_ id: UUID) async throws {
        // The system Stop action may already have stopped the alarm before this intent runs.
        if !archive.sessions.contains(where: { $0.finishedAt == nil && ($0.alarm.id == id || $0.retryID == id) }),
           let alarm = archive.alarms.first(where: { $0.id == id && $0.enabled }) {
            archive.sessions.append(WakeSession(alarm: alarm))
            try persist()
        }
        if let index = archive.sessions.firstIndex(where: { $0.finishedAt == nil && $0.retryID == id }) {
            archive.sessions[index].scheduledTestAt = nil
            archive.sessions[index].quietUntil = nil
            try persist()
        }
        guard let session = archive.sessions.first(where: { $0.finishedAt == nil && ($0.alarm.id == id || $0.retryID == id) }) else { return }
        // Do not stop a system alarm just because the user opens the task screen.
        // If the system Stop button was used, schedule a new system alert instead.
        if try !manager.alarms.contains(where: { ($0.id == session.alarm.id || $0.id == session.retryID) && $0.state == .alerting }) {
            try await armRetry(sessionID: session.id, seconds: 5)
        }
        presented = true
    }
    func test(_ alarm: LocalAlarm, delayed: Bool) async throws {
        if let message = alarm.validationError { throw WakeError.message(message) }
        guard !archive.sessions.contains(where: { $0.finishedAt == nil }) else { throw WakeError.message("请先结束当前任务或取消待响测试") }
        var session = WakeSession(alarm: alarm, isTest: true)
        if delayed {
            try await requestAuthorization()
            let date = Date().addingTimeInterval(15), id = UUID()
            session.scheduledTestAt = date; session.retryAt = date; session.retryID = id
        }
        archive.sessions.append(session)
        do {
            try persist()
            if let id = session.retryID, let date = session.retryAt {
                try await scheduleReplacing(alarm, id: id, at: date)
            } else { presented = true }
        } catch {
            archive.sessions.removeAll { $0.id == session.id }; try? persist(); throw error
        }
    }
    private func armRetry(sessionID: UUID, seconds: Double) async throws {
        guard !retryMutations.contains(sessionID) else { throw WakeError.message("正在安排重响，请稍后重试") }
        retryMutations.insert(sessionID)
        defer { retryMutations.remove(sessionID) }
        guard let index = archive.sessions.firstIndex(where: { $0.id == sessionID && $0.finishedAt == nil }) else { return }
        let old = archive.sessions[index]
        let id = old.retryID ?? UUID(), date = Date().addingTimeInterval(seconds)
        archive.sessions[index].retryID = id; archive.sessions[index].retryAt = date
        do { try persist() } catch { archive.sessions[index] = old; throw error }
        do {
            try await scheduleReplacing(old.alarm, id: id, at: date)

        } catch {
            if let current = archive.sessions.firstIndex(where: { $0.id == sessionID }) {
                archive.sessions[current].retryID = old.retryID
                archive.sessions[current].retryAt = old.retryAt
                archive.sessions[current].quietUntil = old.quietUntil
                archive.sessions[current].snoozeCount = old.snoozeCount
                try? persist()
            }
            throw error
        }
    }
    func progress(taskID: UUID, count: Int) throws {
        guard let session = active, let index = archive.sessions.firstIndex(where: { $0.id == session.id }) else { return }
        guard let task = session.alarm.tasks.first(where: { $0.id == taskID }) else { return }
        let old = archive.sessions[index]
        archive.sessions[index].counts[taskID.uuidString] = min(task.repetitions, max(0, count))
        do { try persist() } catch { archive.sessions[index] = old; throw error }
    }
    func complete(taskID: UUID) async throws {
        guard let session = active, let index = archive.sessions.firstIndex(where: { $0.id == session.id }) else { return }
        guard let task = session.alarm.tasks.first(where: { $0.id == taskID }), session.counts[taskID.uuidString, default: 0] >= task.repetitions else { return }
        let old = archive.sessions[index]
        if !archive.sessions[index].completedTaskIDs.contains(taskID) { archive.sessions[index].completedTaskIDs.append(taskID) }
        do { try persist() } catch { archive.sessions[index] = old; throw error }
        if archive.sessions[index].satisfied { try await finish(sessionID: session.id, manual: false) }
    }
    func finish(sessionID: UUID, manual: Bool) async throws {
        guard finishingSessions.insert(sessionID).inserted else { return }
        defer { finishingSessions.remove(sessionID) }
        // Let an in-flight schedule finish before cancellation so it cannot resurrect a retry.
        while retryMutations.contains(sessionID) { try await Task.sleep(for: .milliseconds(50)) }
        guard let index = archive.sessions.firstIndex(where: { $0.id == sessionID && $0.finishedAt == nil }) else { return }
        archive.sessions[index].endingManually = manual
        try persist()
        let session = archive.sessions[index]
        if let retry = session.retryID { try cancelIfPresent(retry) }
        if !session.isTest {
            if session.alarm.weekdays.isEmpty {
                try cancelIfPresent(session.alarm.id)
                if let alarmIndex = archive.alarms.firstIndex(where: { $0.id == session.alarm.id }) { archive.alarms[alarmIndex].enabled = false }
            } else if try manager.alarms.contains(where: { $0.id == session.alarm.id && $0.state == .alerting }) {
                try manager.stop(id: session.alarm.id)
            }
        }
        archive.sessions[index].finishedAt = Date(); archive.sessions[index].manuallyEnded = manual
        archive.sessions[index].retryID = nil; archive.sessions[index].retryAt = nil
        archive.sessions[index].endingManually = nil
        do { try persist() } catch { archive.sessions[index] = session; throw error }
        archive.sessions.removeAll { $0.finishedAt != nil && $0.createdAt < Date().addingTimeInterval(-30 * 86400) }
        try persist()
        presented = active != nil
        updateMissing(try manager.alarms)
    }
    private func tick() async {
        guard let session = active else { return }
        presented = true
        guard AlarmSystemAccess.canRead(isAuthorized: manager.authorizationState == .authorized, storeLoaded: loaded) else { return }
        if session.satisfied || session.endingManually != nil {
            guard Date() >= nextRetryAttempt else { return }
            do { try await finish(sessionID: session.id, manual: session.endingManually ?? false) }
            catch {
                nextRetryAttempt = Date().addingTimeInterval(30)
                systemStatus = "系统闹钟尚未完成清理：" + error.localizedDescription
            }
            return
        }
        guard !retryMutations.contains(session.id), Date() >= nextRetryAttempt else { return }
        // No foreground audio substitute: the system alarm remains responsible for sound.
        // A non-delayed rehearsal has no system alarm and intentionally exercises tasks only.
        guard !session.isTest || session.retryID != nil else { return }
        do {
            let system = try manager.alarms
            let isRinging = system.contains { ($0.id == session.alarm.id || $0.id == session.retryID) && $0.state == .alerting }
            let retryPending = system.contains { $0.id == session.retryID && $0.state == .scheduled }
            if !isRinging && !retryPending { try await armRetry(sessionID: session.id, seconds: 5) }
        } catch {
            nextRetryAttempt = Date().addingTimeInterval(30)
            self.systemStatus = "系统重响尚未安排成功：" + error.localizedDescription
        }

    }
}

enum WakeError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(text) = self { return text }; return nil }
}

// A UIKit-presented screen must own its dismissal. Its SwiftUI presenter is hidden
// while this full-screen host is visible and may not receive representable updates.
@MainActor
private final class WakeAlarmHostingController: UIHostingController<WakeSessionView> {
    var onClosed: (() -> Void)?
    private var presentationSubscription: AnyCancellable?
    private var closeWork: DispatchWorkItem?
    private var closing = false

    init() {
        super.init(rootView: WakeSessionView(onClose: {}))
        rootView = WakeSessionView(onClose: { [weak self] in self?.requestClose() })
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
        presentationSubscription = AlarmController.shared.$presented
            .receive(on: RunLoop.main)
            .sink { [weak self] presented in
                if !presented { self?.requestClose() }
            }
    }
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func requestClose() {
        guard AlarmController.shared.active == nil else { return }
        closeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.closeWhenReady() }
        closeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }
    private func closeWhenReady() {
        guard AlarmController.shared.active == nil, !closing else { return }
        guard !isBeingPresented && !isBeingDismissed else { requestClose(); return }
        if let child = presentedViewController {
            guard !child.isBeingPresented && !child.isBeingDismissed else { requestClose(); return }
            closing = true
            dismiss(animated: false) { [weak self] in
                self?.closing = false
                self?.requestClose()
            }
        } else if let presenter = presentingViewController {
            closing = true
            // Dismiss from the actual presenting controller, not a SwiftUI binding
            // on the already-covered underlying screen.
            presenter.dismiss(animated: true) { [weak self] in
                self?.closing = false
                self?.onClosed?()
            }
        } else { onClosed?() }
    }
}

private struct WakeAlarmPresenter: UIViewControllerRepresentable {
    var presented: Bool
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func updateUIViewController(_ anchor: UIViewController, context: Context) {
        context.coordinator.anchor = anchor
        context.coordinator.schedule()
    }
    @MainActor
    final class Coordinator {
        weak var anchor: UIViewController?
        var host: WakeAlarmHostingController?
        private var pending: DispatchWorkItem?
        func schedule() {
            pending?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.reconcile() }
            pending = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
        }
        private func reconcile() {
            if AlarmController.shared.presented, AlarmController.shared.active != nil {
                guard host == nil, let root = anchor?.view.window?.rootViewController else { return }
                var top = root
                while let next = top.presentedViewController { top = next }
                guard !top.isBeingDismissed && !top.isBeingPresented else { schedule(); return }
                let view = WakeAlarmHostingController()
                view.onClosed = { [weak self] in
                    self?.host = nil
                    self?.schedule()
                }
                host = view
                top.present(view, animated: true)
            } else {
                host?.requestClose()
            }
        }
    }
}

struct AlarmRootModifier: ViewModifier {
    @ObservedObject private var controller = AlarmController.shared
    @Environment(\.scenePhase) private var phase
    func body(content: Content) -> some View {
        content
            .onAppear { controller.setForeground(true) }
            .onChange(of: phase) { _, value in controller.setForeground(value == .active) }
            .background(WakeAlarmPresenter(presented: controller.presented))
            .alert("任务闹钟", isPresented: Binding(get: { controller.error != nil }, set: { if !$0 { controller.error = nil } })) {
                Button("好") { controller.error = nil }
            } message: { Text(controller.error ?? "") }
    }
}
#endif

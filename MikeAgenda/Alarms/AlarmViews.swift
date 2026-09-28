#if !targetEnvironment(macCatalyst)
import SwiftUI
import UIKit
import AVFoundation

struct LocalAlarmListView: View {
    @ObservedObject private var controller = AlarmController.shared
    @State private var editing: LocalAlarm?
    @State private var error: String?
    @State private var working = false
    @State private var deleting: LocalAlarm?
    var body: some View {
        List {
            Section {
                Label("仅保存在此设备，不依赖服务器或登录", systemImage: "iphone")
                    .font(.footnote).foregroundStyle(.secondary)
                if !controller.authorized {
                    Button("允许系统闹钟") { run { try await controller.requestAuthorization() } }
                }
            } footer: {
                Text("系统保留停止闹钟的能力。App 内任务完成后才记为成功唤醒；系统音量由设备控制。")
            }
            if let status = controller.systemStatus {
                Section("系统闹钟状态") {
                    Text(status).font(.footnote).foregroundStyle(.orange)
                    Button("重试同步") { Task { await controller.retrySystemSync() } }
                }
            }
            if controller.active != nil {
                Section { Button("继续唤醒任务") { controller.presented = true } }
            }
            if !controller.pendingTests.isEmpty {
                Section("待响测试") {
                    ForEach(controller.pendingTests) { session in
                        HStack {
                            Text(session.alarm.name)
                            Spacer()
                            Button("取消") { run { try await controller.finish(sessionID: session.id, manual: true) } }
                        }
                    }
                }
            }
            Section("闹钟") {
                if controller.alarms.isEmpty { Text("还没有闹钟，点击右上角添加").foregroundStyle(.secondary) }
                ForEach(controller.alarms) { alarm in
                    HStack(spacing: 16) {
                        Button { editing = alarm } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(alarm.timeText).font(.system(size: 36, weight: .light, design: .rounded))
                                Text(alarm.name + " · " + alarm.repeatText).font(.subheadline)
                                Text(alarm.tasks.isEmpty ? "请编辑并添加唤醒任务" : alarm.tasks.map { $0.kind.title }.joined(separator: "、")).font(.caption).foregroundStyle(.secondary)
                                if alarm.enabled, let next = alarm.nextFire() {
                                    Text("下次：" + next.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                }
                                if controller.missingSchedules.contains(alarm.id) {
                                    Text("系统未排定，请重新启用或检查授权").font(.caption).foregroundStyle(.red)
                                }
                            }.foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                        Toggle("启用", isOn: Binding(get: { alarm.enabled }, set: { value in
                            var updated = alarm; updated.enabled = value
                            run { try await controller.save(updated) }
                        })).labelsHidden().disabled(working)
                    }
                    .swipeActions {
                        Button("删除", role: .destructive) { deleting = alarm }
                        Button("测试") { run { try await controller.test(alarm, delayed: true) } }.tint(.orange)
                    }
                }
            }
            if !controller.archive.sessions.filter({ $0.finishedAt != nil }).isEmpty {
                Section("最近记录") {
                    ForEach(Array(controller.archive.sessions.filter { $0.finishedAt != nil }.suffix(10).reversed())) { session in
                        VStack(alignment: .leading) {
                            Text((session.isTest ? "测试 · " : "") + session.alarm.name)
                            Text((session.manuallyEnded ? "手动结束" : "任务完成") + " · " + (session.finishedAt ?? session.createdAt).formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("任务闹钟")
        .toolbar { Button { editing = LocalAlarm() } label: { Image(systemName: "plus") }.disabled(working) }
        .sheet(item: $editing) { alarm in NavigationStack { AlarmEditorView(initial: alarm) } }
        .task { await controller.reconcile() }
        .alert("无法完成操作", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("好") { error = nil }
        } message: { Text(error ?? "") }
        .confirmationDialog("删除这个闹钟？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("删除", role: .destructive) { if let deleting { run { try await controller.delete(deleting) } }; deleting = nil }
        }
    }
    private func run(_ action: @escaping () async throws -> Void) {
        working = true
        Task { do { try await action() } catch { self.error = error.localizedDescription }; working = false }
    }
}

private struct AlarmWeekdayPicker: View {
    @Binding var weekdays: [Int]
    private let days = [2, 3, 4, 5, 6, 7, 1]
    private let labels = [1: "日", 2: "一", 3: "二", 4: "三", 5: "四", 6: "五", 7: "六"]
    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 4) {
                ForEach(days, id: \.self) { day in
                    let selected = weekdays.contains(day)
                    Button {
                        if selected { weekdays.removeAll { $0 == day } }
                        else { weekdays.append(day) }
                    } label: {
                        Text(labels[day] ?? "")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(selected ? Color.white : Color.primary)
                            .background(selected ? Color.blue : Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("星期" + (labels[day] ?? ""))
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            HStack(spacing: 10) {
                preset("仅一次", days: [])
                preset("每天", days: Array(1...7))
                preset("工作日", days: [2, 3, 4, 5, 6])
            }
        }
        .padding(.vertical, 8)
    }
    private func preset(_ title: String, days: [Int]) -> some View {
        Button { weekdays = days } label: {
            Text(title).font(.caption.weight(.medium)).frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .tint(Set(weekdays) == Set(days) ? .blue : .secondary)
    }
}

struct AlarmEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var alarm: LocalAlarm
    @State private var error: String?
    @State private var saving = false
    @State private var editingTask: WakeTaskConfiguration?
    @State private var testPresented = false
    @State private var delayedTestNotice = false
    init(initial: LocalAlarm) { _alarm = State(initialValue: initial) }
    private var dateBinding: Binding<Date> {
        Binding(get: { Calendar.current.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: Date()) ?? Date() }, set: {
            alarm.hour = Calendar.current.component(.hour, from: $0); alarm.minute = Calendar.current.component(.minute, from: $0)
        })
    }
    var body: some View {
        Form {
            Section("时间") {
                DatePicker("响铃时间", selection: dateBinding, displayedComponents: .hourAndMinute)
                TextField("名称", text: $alarm.name)
                Toggle("启用", isOn: $alarm.enabled)
            }
            Section {
                AlarmWeekdayPicker(weekdays: $alarm.weekdays)
            } header: {
                Text("重复日期")
            } footer: {
                Text(alarm.repeatText + " · 跟随设备当地时间")
            }
            Section {
                Label("电子闹钟 · 尖锐蜂鸣", systemImage: "speaker.wave.3.fill")
            } header: { Text("声音") } footer: {
                Text("使用内置正弦波电子铃声，由系统闹钟播放。不提供静音或音量设置，实际响度仍受系统音量影响。")
            }
            Section("唤醒任务") {
                Picker("完成规则", selection: $alarm.requireAll) {
                    Text("全部完成").tag(true); Text("任一完成").tag(false)
                }
                ForEach(alarm.tasks) { task in
                    Button { editingTask = task } label: {
                        HStack {
                            Label(task.kind.title, systemImage: task.kind.symbol)
                            Spacer()
                            Text("\(task.repetitions) 次").foregroundStyle(.secondary)
                            if task.validationError != nil { Image(systemName: "exclamationmark.circle").foregroundStyle(.orange) }
                        }
                    }
                }
                .onDelete { alarm.tasks.remove(atOffsets: $0) }
                .onMove { alarm.tasks.move(fromOffsets: $0, toOffset: $1) }
                Menu("添加唤醒任务") {
                    ForEach(WakeTaskKind.allCases) { kind in
                        Button(kind.title, systemImage: kind.symbol) {
                            var task = WakeTaskConfiguration(); task.kind = kind
                            if kind == .scene || kind == .qr || kind == .phrase { task.repetitions = 1 }
                            editingTask = task
                        }
                    }
                }
            }
            Section("测试") {
                Button("演练任务（不触发闹钟）") {
                    if let message = alarm.validationError { error = message } else { testPresented = true }
                }
                Button("15 秒后系统响铃（可锁屏）") {
                    saving = true
                    Task {
                        do { try await AlarmController.shared.test(alarm, delayed: true); delayedTestNotice = true }
                        catch { self.error = error.localizedDescription }
                        saving = false
                    }
                }
                Text("任务演练用于检查识别流程；需要试听系统闹钟时，使用 15 秒锁屏测试。").font(.caption).foregroundStyle(.secondary)
            }
        }
        .disabled(saving)
        .navigationTitle("配置闹钟")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    saving = true
                    Task {
                        do { try await AlarmController.shared.save(alarm); dismiss() }
                        catch { self.error = error.localizedDescription }
                        saving = false
                    }
                }.disabled(saving)
            }
            ToolbarItem(placement: .bottomBar) { EditButton() }
        }
        .sheet(item: $editingTask) { task in
            NavigationStack {
                WakeTaskEditorView(initial: task) { updated in
                    if let index = alarm.tasks.firstIndex(where: { $0.id == updated.id }) { alarm.tasks[index] = updated }
                    else { alarm.tasks.append(updated) }
                }
            }
        }
        .fullScreenCover(isPresented: $testPresented) { AlarmRehearsalView(alarm: alarm) }
        .alert("任务闹钟", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("好") { error = nil }
        } message: { Text(error ?? "") }
        .alert("锁屏测试已安排", isPresented: $delayedTestNotice) {
            Button("返回列表") { dismiss() }
        } message: { Text("将在约 15 秒后响铃，可锁定设备验证。") }
    }
}

struct WakeTaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var task: WakeTaskConfiguration
    var onSave: (WakeTaskConfiguration) -> Void
    @State private var camera = false
    @State private var test = false
    @State private var message: String?
    @State private var processing = false
    init(initial: WakeTaskConfiguration, onSave: @escaping (WakeTaskConfiguration) -> Void) {
        _task = State(initialValue: initial); self.onSave = onSave
    }
    var body: some View {
        Form {
            Section {
                Stepper("要求完成 \(task.repetitions) 次", value: $task.repetitions, in: 1...50)
                switch task.kind {
                case .math:
                    Picker("难度", selection: $task.difficulty) { Text("简单：个位数加减").tag(1); Text("中等：四则运算").tag(2); Text("困难：较大数四则运算").tag(3) }
                    Toggle("必须连续答对", isOn: $task.consecutive)
                case .qr:
                    Text(task.target.isEmpty ? "尚未绑定二维码" : "已绑定：" + task.target).lineLimit(3)
                    Button("扫描绑定二维码") { openCamera() }
                    Text("拍摄二维码后在设备上读取内容，不打开二维码链接。").font(.caption)
                case .scene:
                    Text("建议拍摄固定物体或室内场景，避免光线变化很大的风景。最多 3 张参考照片。")
                    ForEach(Array(task.referenceImages.enumerated()), id: \.offset) { index, bytes in
                        if let image = UIImage(data: bytes) {
                            HStack {
                                Image(uiImage: image).resizable().scaledToFit().frame(height: 110)
                                Button("删除", role: .destructive) { task.referenceImages.remove(at: index) }
                            }
                        }
                    }
                    Button("拍摄参考场景") { openCamera() }.disabled(task.referenceImages.count >= 3)
                    Picker("匹配严格程度", selection: $task.imageDistance) {
                        Text("严格").tag(0.35); Text("适中").tag(0.5); Text("宽松").tag(0.7)
                    }
                    Text("请用测试功能验证不同光线和角度。相似匹配不能证明实际到达地点。").font(.caption)
                case .phrase:
                    TextField("要说的句子", text: $task.target, axis: .vertical)
                    Picker("语言", selection: $task.locale) {
                        Text("普通话").tag("zh-CN"); Text("粤语（香港）").tag("zh-HK"); Text("英语").tag("en-US")
                    }
                    Toggle("完整句子匹配", isOn: $task.strictPhrase)
                    Text("忽略标点、空格和大小写。关闭完整匹配后，允许识别文本包含指定句子。仅使用本地语音识别，请先测试设备支持情况。").font(.caption)
                }
            }
            if processing { ProgressView("正在本机识别…") }
            if let message { Section { Text(message).foregroundStyle(.secondary) } }
            Section { Button("测试这个任务") {
                if let issue = task.validationError { message = issue } else { test = true }
            } }
        }
        .navigationTitle(task.kind.title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("保存") {
                if let issue = task.validationError { message = issue } else { onSave(task); dismiss() }
            }.disabled(processing) }
        }
        .sheet(isPresented: $camera) { WakeCamera { image in process(image) }.ignoresSafeArea() }
        .fullScreenCover(isPresented: $test) {
            NavigationStack {
                WakeTaskRunner(task: task, initialCount: 0, onProgress: { _ in }, onComplete: { test = false })
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("结束测试") { test = false } } }
            }
        }

    }
    private func openCamera() {
        Task {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { message = "此设备没有可用相机"; return }
            guard await AVCaptureDevice.requestAccess(for: .video) else { message = "请在系统设置中允许相机"; return }
            camera = true
        }
    }
    private func process(_ image: UIImage) {
        guard let bytes = wakeJPEG(image) else { message = "照片处理失败"; return }
        if task.kind == .scene { task.referenceImages.append(bytes); return }
        processing = true
        Task {
            do {
                let codes = try await WakeImageVerifier().qr(bytes)
                guard codes.count == 1, let code = codes.first else { throw WakeError.message("请只拍摄一个清晰的二维码后重试") }
                task.target = code; message = "二维码绑定成功"
            } catch { message = error.localizedDescription }
            processing = false
        }
    }
}

struct WakeSessionView: View {
    var onClose: () -> Void
    @ObservedObject private var controller = AlarmController.shared
    @State private var selectedTask: WakeTaskConfiguration?
    @State private var completedTaskToCommit: UUID?
    @State private var emergency = false
    @State private var busy = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            if let session = controller.active {
                List {
                    Section {
                        Text(session.alarm.timeText).font(.system(size: 48, weight: .light, design: .rounded))
                        Text(session.alarm.name).font(.title2)
                        if session.isTest { Label("测试闹钟", systemImage: "testtube.2") }
                        Text("完成唤醒任务以结束本次闹钟").foregroundStyle(.secondary)
                        if let status = controller.systemStatus {
                            Text(status).font(.footnote).foregroundStyle(.orange)
                        }
                    }
                    Section(session.alarm.requireAll ? "按顺序完成全部任务" : "任选一个任务完成") {
                        ForEach(session.alarm.tasks) { task in
                            let done = session.completedTaskIDs.contains(task.id)
                            let firstPending = session.alarm.tasks.first { !session.completedTaskIDs.contains($0.id) }?.id
                            Button { selectedTask = task } label: {
                                HStack {
                                    Label(task.kind.title, systemImage: task.kind.symbol)
                                    Spacer()
                                    if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                                    else { Text("\(session.counts[task.id.uuidString, default: 0])/\(task.repetitions)") }
                                }
                            }.disabled(done || (session.alarm.requireAll && firstPending != task.id))
                        }
                    }
                    Section { Button("紧急结束", role: .destructive) { emergency = true } }
                }
                .navigationTitle("唤醒任务")
                .confirmationDialog("结束本次闹钟？这会记录为手动结束。", isPresented: $emergency, titleVisibility: .visible) {
                    Button("结束本次闹钟", role: .destructive) { perform { try await controller.finish(sessionID: session.id, manual: true) } }
                }
            } else {
                ContentUnavailableView {
                    Label("闹钟已结束", systemImage: "checkmark.circle")
                } actions: {
                    Button("返回") { closeFinishedAlarm() }
                }
                .onAppear { closeFinishedAlarm() }
            }
        }
        .sheet(item: $selectedTask, onDismiss: {
            guard let taskID = completedTaskToCommit else { return }
            completedTaskToCommit = nil
            perform { try await controller.complete(taskID: taskID) }
        }) { task in
            NavigationStack {
                WakeTaskRunner(task: task, initialCount: controller.active?.counts[task.id.uuidString] ?? 0, onProgress: { count in
                    do { try controller.progress(taskID: task.id, count: count) } catch { self.error = error.localizedDescription }
                }, onComplete: {
                    completedTaskToCommit = task.id
                    selectedTask = nil
                })
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("返回任务") { selectedTask = nil } } }
            }.interactiveDismissDisabled()
        }
        .alert("任务闹钟", isPresented: Binding(get: { error != nil || controller.error != nil }, set: { if !$0 { error = nil; controller.error = nil } })) {
            Button("好") { error = nil; controller.error = nil }
        } message: { Text(error ?? controller.error ?? "") }
    }
    private func closeFinishedAlarm() {
        guard controller.active == nil else { return }
        controller.presented = false
        onClose()
    }
    private func perform(_ operation: @escaping () async throws -> Void) {
        busy = true
        Task { do { try await operation() } catch { self.error = error.localizedDescription }; busy = false }
    }
}

// Rehearsals deliberately do not schedule system alarms or mutate a saved definition.
struct AlarmRehearsalView: View {
    var alarm: LocalAlarm
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var completed: Set<UUID> = []
    @State private var counts: [UUID: Int] = [:]
    @State private var selected: WakeTaskConfiguration?
    var body: some View {
        NavigationStack {
            List {
                Section("前台演练 · " + alarm.name) {
                    ForEach(alarm.tasks) { task in
                        Button {
                            selected = task
                        } label: {
                            HStack { Text(task.kind.title); Spacer(); if completed.contains(task.id) { Image(systemName: "checkmark") } }
                        }.disabled(completed.contains(task.id) || (alarm.requireAll && alarm.tasks.first(where: { !completed.contains($0.id) })?.id != task.id))
                    }
                }

            }
            .navigationTitle("整套任务测试")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("结束测试") { dismiss() } } }
        }
        .sheet(item: $selected, onDismiss: {
            if !completed.isEmpty && (!alarm.requireAll || completed.count == alarm.tasks.count) { dismiss() }
        }) { task in
            NavigationStack {
                WakeTaskRunner(task: task, initialCount: counts[task.id] ?? 0, onProgress: { counts[task.id] = $0 }, onComplete: {
                    completed.insert(task.id); selected = nil
                }).toolbar { ToolbarItem(placement: .cancellationAction) { Button("返回") { selected = nil } } }
            }
        }

    }
}
#endif

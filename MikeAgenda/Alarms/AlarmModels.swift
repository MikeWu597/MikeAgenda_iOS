import Foundation

// Stored only in Application Support on this device. No server or account identifiers.
enum WakeTaskKind: String, Codable, CaseIterable, Identifiable {
    case qr, math, scene, phrase
    var id: String { rawValue }
    var title: String {
        switch self {
        case .qr: return "扫描二维码"
        case .math: return "数学题"
        case .scene: return "拍摄指定场景"
        case .phrase: return "说一句话"
        }
    }
    var symbol: String {
        switch self {
        case .qr: return "qrcode.viewfinder"
        case .math: return "function"
        case .scene: return "camera"
        case .phrase: return "mic"
        }
    }
}

struct WakeTaskConfiguration: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: WakeTaskKind = .math
    var repetitions = 3
    var difficulty = 1
    var consecutive = false
    var target = ""
    var locale = "zh-CN"
    var strictPhrase = true
    // JPEGs remain local. Multiple references accommodate light and framing changes.
    var referenceImages: [Data] = []
    var imageDistance = 0.5

    var validationError: String? {
        if !(1...50).contains(repetitions) { return "任务次数需要在 1–50 之间" }
        switch kind {
        case .qr: return target.isEmpty ? "请先扫描并绑定二维码" : nil
        case .scene: return referenceImages.isEmpty ? "请先拍摄参考场景" : nil
        case .phrase: return normalizedWakePhrase(target).isEmpty ? "请输入包含文字或数字的句子" : nil
        case .math: return nil
        }
    }
}

enum AlarmTone: String, Codable, CaseIterable, Identifiable {
    case bright, gentle, pulse
    var id: String { rawValue }
    var title: String {
        switch self { case .bright: return "清晨"; case .gentle: return "柔和"; case .pulse: return "脉冲" }
    }
    var filename: String { "wake_" + rawValue + ".wav" }
}

struct LocalAlarm: Codable, Identifiable, Equatable {
    var id = UUID()
    var name = "起床"
    var hour = 7
    var minute = 0
    // Calendar weekday numbering: Sunday = 1.
    var weekdays: [Int] = []
    var enabled = true
    // Legacy settings retained only to decode older archives; sound always uses AlarmKit.default.
    var tone: AlarmTone = .bright
    var volume: Double = 0.8
    var fadeSeconds = 10
    var allowSnooze = true
    var snoozeMinutes = 3
    var maxSnoozes = 2
    var requireAll = true
    var tasks = [WakeTaskConfiguration()]

    var timeText: String { String(format: "%02d:%02d", hour, minute) }
    var repeatText: String {
        if weekdays.isEmpty { return "仅一次" }
        if weekdays.count == 7 { return "每天" }
        let labels = [1: "日", 2: "一", 3: "二", 4: "三", 5: "四", 6: "五", 7: "六"]
        return "周" + weekdays.sorted().compactMap { labels[$0] }.joined(separator: "、")
    }
    func nextFire(after now: Date = Date(), calendar: Calendar = .current) -> Date? {
        if weekdays.isEmpty {
            return calendar.nextDate(after: now, matching: DateComponents(hour: hour, minute: minute), matchingPolicy: .nextTime)
        }
        return weekdays.compactMap { day in
            calendar.nextDate(after: now, matching: DateComponents(hour: hour, minute: minute, weekday: day), matchingPolicy: .nextTime)
        }.min()
    }
    var validationError: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请输入闹钟名称" }
        if tasks.isEmpty { return "请至少添加一个唤醒任务" }
        return tasks.compactMap(\.validationError).first
    }
}

struct WakeSession: Codable, Identifiable {
    var id = UUID()
    var alarm: LocalAlarm
    var isTest = false
    var createdAt = Date()
    var completedTaskIDs: [UUID] = []
    var counts: [String: Int] = [:]
    var snoozeCount = 0
    var quietUntil: Date?
    var retryID: UUID?
    var retryAt: Date?
    var scheduledTestAt: Date?
    var finishedAt: Date?
    var endingManually: Bool?
    var manuallyEnded = false

    var satisfied: Bool {
        alarm.requireAll
            ? alarm.tasks.allSatisfy { completedTaskIDs.contains($0.id) }
            : !completedTaskIDs.isEmpty
    }
    var ready: Bool { finishedAt == nil && (scheduledTestAt == nil || scheduledTestAt! <= Date()) }
}

struct AlarmArchive: Codable {
    var version = 1
    var systemSoundVersion: Int?
    var removedTaskAlarmIDs: [UUID]?
    var alarms: [LocalAlarm] = []
    var sessions: [WakeSession] = []
}

struct MathQuestion: Equatable {
    var text: String
    var answer: Int
    static func make(difficulty: Int) -> MathQuestion {
        let maxValue = difficulty == 1 ? 9 : (difficulty == 2 ? 30 : 99)
        let a = Int.random(in: 1...maxValue), b = Int.random(in: 1...maxValue)
        switch Int.random(in: 0...(difficulty == 1 ? 1 : 3)) {
        case 0: return MathQuestion(text: "\(a) + \(b)", answer: a + b)
        case 1: return MathQuestion(text: "\(max(a, b)) − \(min(a, b))", answer: abs(a - b))
        case 2:
            let c = Int.random(in: 2...(difficulty == 2 ? 9 : 19))
            return MathQuestion(text: "\(a) × \(c)", answer: a * c)
        default:
            let c = Int.random(in: 2...9)
            return MathQuestion(text: "\(a * c) ÷ \(c)", answer: a)
        }
    }
}

func normalizedWakePhrase(_ text: String) -> String {
    text.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
}

// Remove retired task payloads before decoding the supported task enum. This keeps
// older archives readable without keeping the removed feature in the app.
enum AlarmArchiveMigration {
    static func decode(_ data: Data) throws -> (archive: AlarmArchive, changed: Bool) {
        guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (try JSONDecoder().decode(AlarmArchive.self, from: data), false)
        }
        var changed = false
        var cancelIDs = root["removedTaskAlarmIDs"] as? [String] ?? []
        func removeRetiredTasks(_ alarm: inout [String: Any]) -> Bool {
            guard let tasks = alarm["tasks"] as? [[String: Any]] else { return false }
            let supported = tasks.filter { ($0["kind"] as? String) != "squat" }
            guard supported.count != tasks.count else { return false }
            alarm["tasks"] = supported
            if supported.isEmpty { alarm["enabled"] = false }
            changed = true
            return true
        }
        if var alarms = root["alarms"] as? [[String: Any]] {
            for index in alarms.indices {
                if removeRetiredTasks(&alarms[index]),
                   (alarms[index]["tasks"] as? [[String: Any]])?.isEmpty == true,
                   let id = alarms[index]["id"] as? String, !cancelIDs.contains(id) {
                    cancelIDs.append(id)
                }
            }
            root["alarms"] = alarms
        }
        if var sessions = root["sessions"] as? [[String: Any]] {
            for index in sessions.indices {
                guard var alarm = sessions[index]["alarm"] as? [String: Any], removeRetiredTasks(&alarm) else { continue }
                sessions[index]["alarm"] = alarm
                let taskIDs = Set((alarm["tasks"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String })
                sessions[index]["completedTaskIDs"] = (sessions[index]["completedTaskIDs"] as? [String] ?? []).filter { taskIDs.contains($0) }
                sessions[index]["counts"] = (sessions[index]["counts"] as? [String: Any] ?? [:]).filter { taskIDs.contains($0.key) }
                if taskIDs.isEmpty && (sessions[index]["finishedAt"] == nil || sessions[index]["finishedAt"] is NSNull) {
                    sessions[index]["endingManually"] = true
                }
            }
            root["sessions"] = sessions
        }
        root["removedTaskAlarmIDs"] = cancelIDs
        let cleaned = try JSONSerialization.data(withJSONObject: root)
        return (try JSONDecoder().decode(AlarmArchive.self, from: cleaned), changed)
    }
}

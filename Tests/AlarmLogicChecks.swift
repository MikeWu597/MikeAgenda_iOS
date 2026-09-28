import Foundation

@main struct AlarmLogicChecks {
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 8))!
        var alarm = LocalAlarm()
        let next = alarm.nextFire(after: now, calendar: calendar)!
        assert(calendar.component(.day, from: next) == 29, "Single alarm after today's time goes to tomorrow")
        alarm.weekdays = [2]
        let monday = alarm.nextFire(after: now, calendar: calendar)!
        assert(calendar.component(.day, from: monday) == 5, "Weekly alarm goes to next Monday")
        var ny = calendar; ny.timeZone = TimeZone(identifier: "America/New_York")!
        alarm.hour = 2; alarm.minute = 30; alarm.weekdays = []
        let spring = ny.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 0))!
        assert(alarm.nextFire(after: spring, calendar: ny)! > spring, "DST gap must still produce a future date")

        var qr = WakeTaskConfiguration(); qr.kind = .qr
        assert(qr.validationError != nil)
        qr.target = "wake:kitchen"; assert(qr.validationError == nil)
        let math = WakeTaskConfiguration()
        alarm.tasks = [qr, math]
        var session = WakeSession(alarm: alarm)
        session.completedTaskIDs = [qr.id]
        assert(!session.satisfied, "All mode needs both tasks")
        session.alarm.requireAll = false
        assert(session.satisfied, "Any mode only needs one")
        session.counts[qr.id.uuidString] = 1
        session.retryID = UUID(); session.retryAt = now; session.quietUntil = now
        session.snoozeCount = 2
        var archive = AlarmArchive(); archive.alarms = [alarm]; archive.sessions = [session]
        let restored = try JSONDecoder().decode(AlarmArchive.self, from: JSONEncoder().encode(archive))
        assert(restored.sessions[0].counts[qr.id.uuidString] == 1)
        assert(restored.sessions[0].retryID == session.retryID)
        assert(restored.sessions[0].snoozeCount == 2 && restored.sessions[0].quietUntil == now)
        assert(normalizedWakePhrase(" 你好，世界！Hello ") == "你好世界hello")

        // Old files must load after the retired enum case is removed entirely.
        var oldRoot = try JSONSerialization.jsonObject(with: JSONEncoder().encode(archive)) as! [String: Any]
        var oldAlarms = oldRoot["alarms"] as! [[String: Any]]
        var oldTasks = oldAlarms[0]["tasks"] as! [[String: Any]]
        oldTasks[1]["kind"] = "squat"
        oldAlarms[0]["tasks"] = oldTasks
        var onlyRetired = oldAlarms[0]
        let retiredAlarmID = UUID()
        onlyRetired["id"] = retiredAlarmID.uuidString
        onlyRetired["tasks"] = [oldTasks[1]]
        oldRoot["alarms"] = [oldAlarms[0], onlyRetired]
        var oldSessions = oldRoot["sessions"] as! [[String: Any]]
        oldSessions[0]["alarm"] = onlyRetired
        oldSessions[0]["completedTaskIDs"] = [math.id.uuidString]
        oldSessions[0]["counts"] = [math.id.uuidString: 2]
        oldRoot["sessions"] = oldSessions
        let migrated = try AlarmArchiveMigration.decode(JSONSerialization.data(withJSONObject: oldRoot))
        assert(migrated.changed)
        assert(migrated.archive.alarms[0].tasks.map(\.id) == [qr.id])
        assert(migrated.archive.alarms[0].enabled, "Mixed alarms retain their remaining tasks")
        assert(!migrated.archive.alarms[1].enabled && migrated.archive.alarms[1].tasks.isEmpty)
        assert(migrated.archive.removedTaskAlarmIDs == [retiredAlarmID])
        assert(migrated.archive.sessions[0].endingManually == true)
        assert(migrated.archive.sessions[0].completedTaskIDs.isEmpty && migrated.archive.sessions[0].counts.isEmpty)
        assert(migrated.archive.sessions[0].retryID == session.retryID, "Keep IDs until system cleanup succeeds")
        let secondPass = try AlarmArchiveMigration.decode(JSONEncoder().encode(migrated.archive))
        assert(!secondPass.changed, "Migration must be idempotent")
        assert(!WakeTaskKind.allCases.map(\.rawValue).contains("squat"))

        for difficulty in 1...3 {
            for _ in 0..<100 {
                let question = MathQuestion.make(difficulty: difficulty)
                let fields = question.text.split(separator: " ")
                let a = Int(fields[0])!, b = Int(fields[2])!
                switch fields[1] {
                case "+": assert(question.answer == a + b)
                case "−": assert(question.answer == a - b)
                case "×": assert(question.answer == a * b)
                default: assert(b != 0 && a % b == 0 && question.answer == a / b)
                }
            }
        }
        print("Alarm logic checks passed: scheduling, DST, validation, persistence, completion, retired-task migration, math, phrase normalization")
    }
}

import Foundation

@MainActor
private final class FakeAlarmSystem {
    var alarms: [UUID: String] = [:]
    var events: [String] = []
    var failCreation: Set<String> = []
    var failRemoval = false
    func remove(_ id: UUID) throws {
        events.append("remove")
        if failRemoval { throw NSError(domain: "FakeAlarmSystem", code: 2) }
        alarms.removeValue(forKey: id)
    }
    func create(_ id: UUID, _ configuration: String) async throws {
        events.append("create:" + configuration)
        // Simulate a daemon that rejects duplicate IDs / exhausted capacity.
        guard alarms[id] == nil, !failCreation.contains(configuration) else {
            throw NSError(domain: "com.apple.AlarmKit.Alarm", code: 0)
        }
        alarms[id] = configuration
    }
}

@main @MainActor struct AlarmSchedulingChecks {
    static func main() async throws {
        assert(!AlarmSystemAccess.canRead(isAuthorized: false, storeLoaded: true))
        assert(!AlarmSystemAccess.canRead(isAuthorized: true, storeLoaded: false))
        assert(AlarmSystemAccess.canRead(isAuthorized: true, storeLoaded: true))
        let id = UUID()
        let system = FakeAlarmSystem()
        system.alarms[id] = "original-time"
        try await AlarmScheduleWriter.replace(id: id, previous: "original-time", desired: "edited-time", remove: system.remove, create: system.create)
        assert(system.alarms[id] == "edited-time")
        assert(system.events == ["remove", "create:edited-time"], "Never schedule over a live ID")

        system.events = []; system.failCreation = ["rejected"]
        do {
            try await AlarmScheduleWriter.replace(id: id, previous: "edited-time", desired: "rejected", remove: system.remove, create: system.create)
            assertionFailure("Should report creation failure")
        } catch AlarmScheduleFailure.creationFailed { }
        assert(system.alarms[id] == "edited-time", "Failed edit must restore previous schedule")
        assert(system.events == ["remove", "create:rejected", "create:edited-time"])

        system.events = []; system.failRemoval = true
        do {
            try await AlarmScheduleWriter.replace(id: id, previous: "edited-time", desired: "new", remove: system.remove, create: system.create)
            assertionFailure("Should report cancellation failure")
        } catch { }
        assert(system.events == ["remove"] && system.alarms[id] == "edited-time")

        system.events = []; system.failRemoval = false; system.failCreation = ["edited-time", "rejected"]
        do {
            try await AlarmScheduleWriter.replace(id: id, previous: "edited-time", desired: "rejected", remove: system.remove, create: system.create)
            assertionFailure("Should distinguish failed restoration")
        } catch AlarmScheduleFailure.restoreFailed { }
        assert(system.alarms[id] == nil)

        let fresh = UUID(); system.events = []; system.failCreation = []
        try await AlarmScheduleWriter.replace(id: fresh, previous: Optional<String>.none, desired: "fresh", remove: system.remove, create: system.create)
        assert(system.events == ["create:fresh"] && system.alarms[fresh] == "fresh")
        print("Alarm scheduling checks passed: authorization gate, duplicate IDs, replacement, rollback, removal failure, restoration failure, fresh scheduling")
    }
}

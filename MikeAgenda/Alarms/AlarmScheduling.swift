import Foundation

/// AlarmKit is not treated as an upsert API. Replacement explicitly removes the
/// old request, and restores its original schedule if creation fails.
@MainActor
enum AlarmScheduleWriter {
    static func replace<Configuration>(
        id: UUID,
        previous: Configuration?,
        desired: Configuration,
        remove: (UUID) throws -> Void,
        create: (UUID, Configuration) async throws -> Void
    ) async throws {
        if previous != nil { try remove(id) }
        do {
            try await create(id, desired)
        } catch {
            let creationError = error
            if let previous {
                do { try await create(id, previous) }
                catch { throw AlarmScheduleFailure.restoreFailed(creation: creationError, restoration: error) }
            }
            throw AlarmScheduleFailure.creationFailed(creationError)
        }
    }
}

enum AlarmScheduleFailure: LocalizedError {
    case creationFailed(Error)
    case restoreFailed(creation: Error, restoration: Error)
    var errorDescription: String? {
        switch self {
        case .creationFailed:
            return "系统未能保存这次闹钟修改，原有配置已保留。请稍后重试。"
        case .restoreFailed:
            return "系统未能保存修改，也未能恢复原定提醒。本机配置仍保留，请重新启用此闹钟。"
        }
    }
}

struct AlarmSystemAccess {
    static func canRead(isAuthorized: Bool, storeLoaded: Bool) -> Bool { isAuthorized && storeLoaded }
}

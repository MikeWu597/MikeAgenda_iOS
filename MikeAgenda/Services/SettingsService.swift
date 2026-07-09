import SwiftUI
import Combine

final class SettingsService: ObservableObject {
    static let shared = SettingsService()

    private let refreshKey = "mikeagenda.refreshInterval"

    @Published var colorMode: String {
        didSet { ConnectionProfileStore.saveColorMode(colorMode) }
    }

    @Published var refreshInterval: Int? {
        didSet {
            if let interval = refreshInterval {
                UserDefaults.standard.set(interval, forKey: refreshKey)
            } else {
                UserDefaults.standard.removeObject(forKey: refreshKey)
            }
        }
    }

    @Published var isTeaching: Bool = false

    var effectiveColorScheme: ColorScheme? {
        switch colorMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private init() {
        colorMode = ConnectionProfileStore.loadColorMode()
        let raw = UserDefaults.standard.object(forKey: refreshKey) as? Int
        refreshInterval = (raw != nil && raw! > 0) ? raw : nil
    }

    func loadTeachingStatus() async {
        do {
            isTeaching = try await APIClient.shared.getTeachingStatus()
        } catch {
            isTeaching = false
        }
    }

    func saveTeachingStatus() async throws {
        try await APIClient.shared.setTeachingStatus(isTeaching)
    }
}

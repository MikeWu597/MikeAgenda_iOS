import Foundation
import Combine

final class SessionService: ObservableObject {
    static let shared = SessionService()

    @Published var session: String?
    @Published var isAuthenticated = false
    @Published var profileVersion = 0

    private init() {
        session = ConnectionProfileStore.loadSession()
        isAuthenticated = session != nil
        APIClient.shared.onUnauthorized = { [weak self] in
            self?.clear()
        }
    }

    func save(_ token: String) {
        session = token
        isAuthenticated = true
        ConnectionProfileStore.saveSession(token)
    }

    func clear() {
        session = nil
        isAuthenticated = false
        ConnectionProfileStore.clearSession()
        ConnectionProfileStore.clearWebCookies()
    }

    func notifyProfileChanged() {
        profileVersion += 1
    }
}

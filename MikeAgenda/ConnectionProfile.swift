import Foundation
import Security

struct ConnectionProfile: Equatable {
    var domain: String = ""
    var username: String = ""
    var password: String = ""

    var trimmedDomain: String {
        domain.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isComplete: Bool {
        !trimmedDomain.isEmpty && !trimmedUsername.isEmpty && !password.isEmpty
    }

    var normalizedBaseURL: URL? {
        guard !trimmedDomain.isEmpty else {
            return nil
        }

        let candidate = trimmedDomain.contains("://") ? trimmedDomain : "https://\(trimmedDomain)"
        guard var components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              let host = components.host,
              !host.isEmpty else {
            return nil
        }

        components.scheme = scheme
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
    }

    var reloadToken: String {
        [trimmedDomain, trimmedUsername, password].joined(separator: "|")
    }
}

enum ConnectionProfileStore {
    private static let domainKey = "mikeagenda.domain"
    private static let usernameKey = "mikeagenda.username"
    private static let passwordKey = "mikeagenda.password"
    private static let webCookiesKey = "mikeagenda.web.cookies"
    private static let store = NativeStore()

    static func load() -> ConnectionProfile {
        ConnectionProfile(
            domain: store.value(forKey: domainKey) ?? "",
            username: store.value(forKey: usernameKey) ?? "",
            password: store.secureValue(forKey: passwordKey) ?? ""
        )
    }

    static func save(_ profile: ConnectionProfile) {
        store.setValue(profile.trimmedDomain, forKey: domainKey)
        store.setValue(profile.trimmedUsername, forKey: usernameKey)

        do {
            try store.setSecureValue(profile.password, forKey: passwordKey)
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }

    static func clear() {
        store.removeValue(forKey: domainKey)
        store.removeValue(forKey: usernameKey)
        clearWebCookies()

        do {
            try store.removeSecureValue(forKey: passwordKey)
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }

    static func loadWebCookies() -> String {
        store.value(forKey: webCookiesKey) ?? ""
    }

    static func saveWebCookies(_ value: String) {
        store.setValue(value, forKey: webCookiesKey)
    }

    static func clearWebCookies() {
        store.removeValue(forKey: webCookiesKey)
    }

    private static let colorModeKey = "mikeagenda.colorMode"

    static func loadColorMode() -> String {
        store.value(forKey: colorModeKey) ?? "system"
    }

    static func saveColorMode(_ mode: String) {
        store.setValue(mode, forKey: colorModeKey)
    }
}

final class NativeStore {
    private let defaults = UserDefaults.standard
    private let service = "cn.matrixecho.MikeAgenda"

    func value(forKey key: String) -> String? {
        defaults.string(forKey: key)
    }

    func setValue(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    func removeValue(forKey key: String) {
        defaults.removeObject(forKey: key)
    }

    func secureValue(forKey key: String) -> String? {
        var query = keychainQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    func setSecureValue(_ value: String, forKey key: String) throws {
        let data = Data(value.utf8)
        let query = keychainQuery(forKey: key)
        let attributes = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus == errSecItemNotFound {
            var insertQuery = query
            insertQuery[kSecValueData as String] = data
            let insertStatus = SecItemAdd(insertQuery as CFDictionary, nil)
            guard insertStatus == errSecSuccess else {
                throw NSError(domain: "NativeStore", code: Int(insertStatus), userInfo: [NSLocalizedDescriptionKey: "Unable to save secure value."])
            }
            return
        }

        throw NSError(domain: "NativeStore", code: Int(updateStatus), userInfo: [NSLocalizedDescriptionKey: "Unable to update secure value."])
    }

    func removeSecureValue(forKey key: String) throws {
        let status = SecItemDelete(keychainQuery(forKey: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: "NativeStore", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Unable to remove secure value."])
        }
    }

    private func keychainQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}

extension String {
    var jsEscapedLiteral: String {
        let data = try? JSONSerialization.data(withJSONObject: [self], options: [])
        let arrayString = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        return String(arrayString.dropFirst().dropLast())
    }

    var htmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

import Foundation
import Security

// MARK: - KeychainHelper

enum KeychainHelper {

    private static let service = "com.namah.wellness"

    // MARK: - Data

    static func save(_ data: Data, for key: String) {
        delete(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - String Convenience

    static func saveString(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        save(data, for: key)
    }

    static func loadString(for key: String) -> String? {
        guard let data = load(for: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

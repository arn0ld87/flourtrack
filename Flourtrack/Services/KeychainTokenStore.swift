import Foundation
import SwiftData

/// Speichert JWT und Session-Informationen sicher im iOS Keychain.
/// Nicht im SwiftData-Model, da Keychain verschlüsselter und robuster ist.
enum KeychainTokenStore {
    private static let service = "app.flourtrack"
    private static let account = "auth_token"
    private static let userIdAccount = "public_user_id"
    private static let providerAccount = "account_provider"

    static func save(token: String, publicUserId: String, provider: String) {
        save(key: account, value: token)
        save(key: userIdAccount, value: publicUserId)
        save(key: providerAccount, value: provider)
    }

    static func token() -> String? {
        load(key: account)
    }

    static func publicUserId() -> String? {
        load(key: userIdAccount)
    }

    static func provider() -> String? {
        load(key: providerAccount)
    }

    static func clear() {
        delete(key: account)
        delete(key: userIdAccount)
        delete(key: providerAccount)
    }

    static var isAuthenticated: Bool {
        token() != nil
    }

    // MARK: - Private Keychain Operations

    private static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Lösche vorhandenen Eintrag
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

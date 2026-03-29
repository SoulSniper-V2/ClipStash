import Foundation
import Security

/// Secure storage for API keys and sensitive settings.
enum KeychainHelper {
    
    // MARK: - Save

    /// Save a string value to the Keychain securely. Overwrites existing values.
    static func save(_ value: String, service: String = "clipstash", account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        
        // Delete existing item first to avoid errSecDuplicateItem
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    // MARK: - Load

    /// Load a string value from the Keychain.
    static func load(service: String = "clipstash", account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        
        return string
    }

    // MARK: - Delete

    /// Delete an item from the Keychain.
    static func delete(service: String = "clipstash", account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Error

    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Failed to save to Keychain. OSStatus: \(status)"
            }
        }
    }
}

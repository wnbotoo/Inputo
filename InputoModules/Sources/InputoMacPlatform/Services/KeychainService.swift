import Foundation
import Security

public struct KeychainService {
    private let service = "app.inputo.provider"
    private let account = "openai-compatible-api-key"

    public init() {}

    public func readAPIKey() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return ""
        }
        guard status == errSecSuccess else {
            throw KeychainError.unhandled(status)
        }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            return ""
        }
        return value
    }

    public func saveAPIKey(_ value: String) {
        let data = Data(value.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        if value.isEmpty {
            SecItemDelete(baseQuery as CFDictionary)
            return
        }

        let update: [String: Any] = [
            kSecValueData as String: data
        ]
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}

public enum KeychainError: LocalizedError {
    case unhandled(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .unhandled(let status):
            return "Keychain error \(status)."
        }
    }
}

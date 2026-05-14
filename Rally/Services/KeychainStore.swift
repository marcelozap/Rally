import Foundation
import Security

/// Stores JWT for authenticated Rally API calls.
final class KeychainStore {
    static let shared = KeychainStore()

    private let service = "com.marcelozap.rally.auth"
    private let account = "jwt"

    private init() {}

    var token: String? {
        get {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var out: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &out)
            guard status == errSecSuccess,
                  let data = out as? Data,
                  let str = String(data: data, encoding: .utf8) else {
                return nil
            }
            return str
        }
        set {
            if let newValue {
                guard let data = newValue.data(using: .utf8) else { return }
                SecItemDelete(baseQuery as CFDictionary)
                var q = baseQuery
                q[kSecValueData as String] = data
                q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
                SecItemAdd(q as CFDictionary, nil)
            } else {
                SecItemDelete(baseQuery as CFDictionary)
            }
        }
    }

    func clearToken() {
        token = nil
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

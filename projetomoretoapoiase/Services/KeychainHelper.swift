import Foundation
import Security

// MARK: - Armazenamento Criptografado no Keychain Nativo do iOS (Token JWT)
public final class KeychainHelper {
    public static let shared = KeychainHelper()
    private let service = "com.vakinha.projetomoretoapoiase"
    public let jwtTokenKey = "auth_token"
    
    private init() {}
    
    @discardableResult
    public func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    public func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    public func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    public var currentJWTToken: String? {
        get { get(key: jwtTokenKey) }
        set {
            if let token = newValue, !token.isEmpty {
                save(key: jwtTokenKey, value: token)
            } else {
                delete(key: jwtTokenKey)
            }
        }
    }
}

// MARK: - Gerenciador de Sessão do Usuário Autenticado
public final class SessionManager {
    public static let shared = SessionManager()
    private let userDefaultsKey = "com.vakinha.current_user"
    
    private init() {}
    
    public func saveUserSession(_ user: AppUser, token: String? = nil) {
        if let token = token, !token.isEmpty {
            KeychainHelper.shared.currentJWTToken = token
        }
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    public func loadUserSession() -> AppUser? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let user = try? JSONDecoder().decode(AppUser.self, from: data) else {
            return nil
        }
        return user
    }
    
    public func clearSession() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        KeychainHelper.shared.delete(key: KeychainHelper.shared.jwtTokenKey)
    }
}

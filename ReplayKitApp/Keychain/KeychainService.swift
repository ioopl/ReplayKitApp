import Foundation
import Security
import CryptoKit

public protocol KeychainServiceProtocol {
    func generateSecureEnclaveKey() throws
    func getOrCreateSymmetricKey() throws -> SymmetricKey
    func getSymmetricKey() throws -> SymmetricKey?
    func deleteSymmetricKey() throws
}

public class SharedKeychainManager: KeychainServiceProtocol {
    public static let shared = SharedKeychainManager()
    
    // Replace with your actual App Group ID (must match Entitlements)
    public static let accessGroup = "group.com.apkia.replaykitapp.shared-group"
    public static let keyTag = "com.apkia.replaykitapp.session-key"
    public static let enclaveTag = "com.apkia.replaykitapp.enclave-key"
    
    private init() {}
    
    /// Generates a hardware-bound key pair in the Secure Enclave.
    /// On Simulators, falls back to a standard Software EC key pair if Enclave is unavailable.
    /**
    Secure Enclave Interactions: In generateSecureEnclaveKey(), the manager utilizes:
    kSecAttrTokenIDSecureEnclave to instruct iOS to build the key pair in hardware.
    SecAccessControl with flags [.userPresence, .privateKeyUsage] to bind the key usage directly to biometrics (FaceID/TouchID).
    */
    public func generateSecureEnclaveKey() throws {
        var error: Unmanaged<CFError>?
        
        // Require passcode or biometrics for access, and lock usage to this device.
        guard let accessControl = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            [.userPresence, .privateKeyUsage],
            &error
        ) else {
            throw error?.takeRetainedValue() ?? NSError(domain: "KeychainError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create Access Control Settings"])
        }
        
        var attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave, // Hardware-bound
            kSecAttrAccessGroup as String: Self.accessGroup,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: Self.enclaveTag.data(using: .utf8)!,
                kSecAttrAccessControl as String: accessControl
            ]
        ]
        
        var publicKey, privateKey: SecKey?
        var status = SecKeyGeneratePair(attributes as CFDictionary, &publicKey, &privateKey)
        
        // Fallback for missing entitlements / simulator environment
        if status == -34018 {
            attributes.removeValue(forKey: kSecAttrAccessGroup as String)
            status = SecKeyGeneratePair(attributes as CFDictionary, &publicKey, &privateKey)
        }
        
        if status == errSecSuccess {
            print("Secure Enclave Key Pair generated successfully.")
            return
        }
        
        // Fallback for Simulators (Secure Enclave is not available in Simulator)
        print("Secure Enclave key generation failed (status: \(status)). Attempting software key generation fallback...")
        
        var fallbackAttributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrAccessGroup as String: Self.accessGroup,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: Self.enclaveTag.data(using: .utf8)!
            ]
        ]
        
        var fallbackStatus = SecKeyGeneratePair(fallbackAttributes as CFDictionary, &publicKey, &privateKey)
        if fallbackStatus == -34018 {
            fallbackAttributes.removeValue(forKey: kSecAttrAccessGroup as String)
            fallbackStatus = SecKeyGeneratePair(fallbackAttributes as CFDictionary, &publicKey, &privateKey)
        }
        
        guard fallbackStatus == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(fallbackStatus))
        }
        print("Fallback Software Key Pair generated successfully.")
    }
    
    /**
     Used by both Option B and C.
     
     Keychain Interactions: In getOrCreateSymmetricKey() and getSymmetricKey(), the manager utilizes:
     kSecClassGenericPassword to save the raw 256-bit symmetric key (SymmetricKey) in the Keychain.
     kSecAttrAccessGroup with group.com.example.shared-group to make the key readable by both the main app and the background Broadcast Extension.
     */
    /// Retrieves or generates a 256-bit symmetric session key.
    public func getOrCreateSymmetricKey() throws -> SymmetricKey {
        if let existingKey = try getSymmetricKey() {
            return existingKey
        }
        
        // Generate new 256-bit key
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.keyTag,
            kSecAttrAccessGroup as String: Self.accessGroup,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        var status = SecItemAdd(query as CFDictionary, nil)
        
        // Fallback if target lacks App Group signing configuration during tests
        if status == -34018 {
            query.removeValue(forKey: kSecAttrAccessGroup as String)
            status = SecItemAdd(query as CFDictionary, nil)
        }
        
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        
        return newKey
    }
    
    /// Retrieves the shared symmetric key from the shared keychain.
    public func getSymmetricKey() throws -> SymmetricKey? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.keyTag,
            kSecAttrAccessGroup as String: Self.accessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        var status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == -34018 {
            query.removeValue(forKey: kSecAttrAccessGroup as String)
            status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        }
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess, let keyData = dataTypeRef as? Data else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        
        return SymmetricKey(data: keyData)
    }
    
    /// Deletes the symmetric key from the shared keychain.
    public func deleteSymmetricKey() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: Self.keyTag,
            kSecAttrAccessGroup as String: Self.accessGroup
        ]
        
        var status = SecItemDelete(query as CFDictionary)
        
        if status == -34018 {
            query.removeValue(forKey: kSecAttrAccessGroup as String)
            status = SecItemDelete(query as CFDictionary)
        }
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}

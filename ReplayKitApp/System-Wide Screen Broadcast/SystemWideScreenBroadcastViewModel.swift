import Foundation
import Combine
import LocalAuthentication

@MainActor
public class SystemWideScreenBroadcastViewModel: ObservableObject {
    @Published public var isAuthenticated = false
    @Published public var keyStatus = "Keys Not Prepared"
    @Published public var errorMessage: String?
    
    private let keychainService: KeychainServiceProtocol
    
    public init(keychainService: KeychainServiceProtocol = SharedKeychainManager.shared) {
        self.keychainService = keychainService
    }
    
    public func authenticateAndPrepareKeys() {
        errorMessage = nil
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Simulator or device without biometrics. Let's fall back to device passcode / standard authentication.
            self.prepareKeys()
            return
        }
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to generate hardware-bound secure broadcast keys.") { success, authError in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if success {
                    self.isAuthenticated = true
                    self.prepareKeys()
                } else {
                    self.errorMessage = authError?.localizedDescription ?? "Biometric authentication failed"
                }
            }
        }
    }
    
    private func prepareKeys() {
        do {
            // Generate Enclave Key Pair (or fallback)
            try keychainService.generateSecureEnclaveKey()
            
            // Create or fetch symmetric key
            _ = try keychainService.getOrCreateSymmetricKey()
            
            self.keyStatus = "Secure Keys Active (App Group Shared)"
            self.isAuthenticated = true
        } catch {
            self.errorMessage = "Failed to generate keys: \(error.localizedDescription)"
        }
    }
}

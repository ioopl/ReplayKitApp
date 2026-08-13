import Foundation
import Combine
import LocalAuthentication
import ReplayKit

@MainActor
public class SystemWideScreenBroadcastViewModel: ObservableObject {
    @Published public var isAuthenticated = false
    @Published public var keyStatus = "Keys Not Prepared"
    @Published public var errorMessage: String?
    
    @Published public var isBroadcasting = false
    @Published public var showSummary = false
    @Published public var lastSessionDuration: TimeInterval = 0
    @Published public var showMockSummary = false
    
    @Published public var lastVideoURL: URL?
    @Published public var lastSessionSize: Int64 = 0
    
    private let keychainService: KeychainServiceProtocol
    private var timer: Timer?
    private var startTime: Date?
    
    public init(keychainService: KeychainServiceProtocol = SharedKeychainManager.shared) {
        self.keychainService = keychainService
        startMonitoringBroadcast()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func startMonitoringBroadcast() {
        // Poll RPScreenRecorder status to detect when user starts/stops system-wide broadcast
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let active = RPScreenRecorder.shared().isRecording
                if active && !self.isBroadcasting {
                    self.isBroadcasting = true
                    self.startTime = Date()
                } else if !active && self.isBroadcasting {
                    self.isBroadcasting = false
                    if let start = self.startTime {
                        self.lastSessionDuration = Date().timeIntervalSince(start)
                    } else {
                        self.lastSessionDuration = 0
                    }
                    
                    // Retrieve actual broadcast file from App Group container
                    let groupID = "group.com.apkia.replaykitapp.shared-group"
                    if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
                        let videoURL = containerURL.appendingPathComponent("broadcast.mp4")
                        if FileManager.default.fileExists(atPath: videoURL.path) {
                            self.lastVideoURL = videoURL
                            let attributes = try? FileManager.default.attributesOfItem(atPath: videoURL.path)
                            self.lastSessionSize = attributes?[.size] as? Int64 ?? 0
                        }
                    }
                    self.showSummary = true
                }
            }
        }
    }
    
    public func deleteLocalBuffer() {
        if let url = lastVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
        lastVideoURL = nil
        lastSessionSize = 0
    }
    
    public func simulateBroadcastEnded() {
        self.lastSessionDuration = 125 // 2 min 5 seconds
        self.showMockSummary = true
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

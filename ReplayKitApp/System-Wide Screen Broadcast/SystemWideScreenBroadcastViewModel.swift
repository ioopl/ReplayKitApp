import Foundation
import Combine
import LocalAuthentication
import ReplayKit
import UIKit

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
    
    /// Frame records read from the shared App Group UserDefaults (written by SampleHandler every 10 frames)
    @Published public var records: [FrameRecord] = []
    
    private let keychainService: KeychainServiceProtocol
    private var pollingTimer: Timer?
    private var startTime: Date?
    private let groupID = "group.com.apkia.replaykitapp.shared-group"
    
    public init(keychainService: KeychainServiceProtocol = SharedKeychainManager.shared) {
        self.keychainService = keychainService
        startMonitoringBroadcast()
    }
    
    deinit {
        pollingTimer?.invalidate()
    }
    
    // MARK: - Broadcast monitoring + ledger polling
    
    private func startMonitoringBroadcast() {
        // Poll RPScreenRecorder status to detect when user starts/stops system-wide broadcast
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let active = RPScreenRecorder.shared().isRecording
                if active && !self.isBroadcasting {
                    self.isBroadcasting = true
                    self.startTime = Date()
                    self.records.removeAll()
                } else if !active && self.isBroadcasting {
                    self.isBroadcasting = false
                    if let start = self.startTime {
                        self.lastSessionDuration = Date().timeIntervalSince(start)
                    } else {
                        self.lastSessionDuration = 0
                    }
                    
                    // Retrieve actual broadcast file from App Group container
                    if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.groupID) {
                        let videoURL = containerURL.appendingPathComponent("broadcast.mp4")
                        if FileManager.default.fileExists(atPath: videoURL.path) {
                            self.lastVideoURL = videoURL
                            let attributes = try? FileManager.default.attributesOfItem(atPath: videoURL.path)
                            self.lastSessionSize = attributes?[.size] as? Int64 ?? 0
                        }
                    }
                    
                    // Load any remaining frame metadata
                    self.loadFrameMetadata()
                    self.showSummary = true
                }
                
                // While broadcasting: poll frame metadata every tick
                if self.isBroadcasting {
                    self.loadFrameMetadata()
                }
            }
        }
    }
    
    private func loadFrameMetadata() {
        guard let defaults = UserDefaults(suiteName: groupID) else { return }
        guard let entries = defaults.array(forKey: "frameMetadata") as? [[String: Any]] else { return }
        
        // Map raw dicts → FrameRecord, skipping already-loaded indices
        let existingIndices = Set(records.map { $0.index })
        var newRecords = records
        
        for entry in entries {
            guard let index = entry["index"] as? Int,
                  !existingIndices.contains(index),
                  let sha256 = entry["sha256"] as? String,
                  let timestamp = entry["timestamp"] as? String,
                  let sizeKB = entry["sizeKB"] as? String,
                  let rawSize = entry["rawSize"] as? Int,
                  let previousHash = entry["previousHash"] as? String,
                  let chainHash = entry["chainHash"] as? String,
                  let resolution = entry["resolution"] as? String
            else { continue }
            
            // Decode thumbnail
            var thumbnail: UIImage?
            if let base64 = entry["thumbBase64"] as? String,
               let data = Data(base64Encoded: base64) {
                thumbnail = UIImage(data: data)
            }
            
            let record = FrameRecord(
                id: UUID(),
                index: index,
                timestamp: timestamp,
                sizeKB: sizeKB,
                rawSize: rawSize,
                sha256: sha256,
                previousHash: previousHash,
                chainHash: chainHash,
                isChainValid: true,
                isEncrypted: true,
                thumbnail: thumbnail,
                hexDump: "",
                sessionID: "SampleHandler",
                resolution: resolution
            )
            newRecords.append(record)
        }
        
        // Keep sorted and capped at 20
        newRecords.sort { $0.index < $1.index }
        if newRecords.count > 20 { newRecords = Array(newRecords.suffix(20)) }
        records = newRecords
    }
    
    // MARK: - Actions
    
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
            
            // Sync the current pipeline choice to shared UserDefaults so SampleHandler can read it
            syncPipelineToAppGroup()
        } catch {
            self.errorMessage = "Failed to generate keys: \(error.localizedDescription)"
        }
    }
    
    /// Write the current CaptureSettings.hashingPipeline into the shared App Group UserDefaults
    /// so the broadcast extension's SampleHandler can read it.
    public func syncPipelineToAppGroup() {
        let pipeline = CaptureSettings.shared.hashingPipeline.rawValue
        if let defaults = UserDefaults(suiteName: groupID) {
            defaults.set(pipeline, forKey: "captureSettings.hashingPipeline")
            defaults.synchronize()
        }
    }
}

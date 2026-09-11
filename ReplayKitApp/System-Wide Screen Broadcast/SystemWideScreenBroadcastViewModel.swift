import Foundation
import Combine
import LocalAuthentication
import ReplayKit
import AVFoundation
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
    @Published public var photosSaveMessage: String?
    
    /// Frame records read from the shared App Group UserDefaults (written by SampleHandler every 10 frames)
    @Published public var records: [FrameRecord] = []
    @Published public var lastSessionID: String?
    
    private let keychainService: KeychainServiceProtocol
    private let photosLibraryService: PhotosLibraryServiceProtocol
    private var pollingTimer: Timer?
    private var startTime: Date?
    private var extensionWasActive = false
    private var activeBroadcastSessionID: String?
    private let groupID = "group.com.apkia.replaykitapp.shared"
    private let outputDirectoryName = "BroadcastOutput"
    
    @MainActor
    public init(
        keychainService: KeychainServiceProtocol = SharedKeychainManager.shared,
        photosLibraryService: PhotosLibraryServiceProtocol? = nil
    ) {
        self.keychainService = keychainService
        self.photosLibraryService = photosLibraryService ?? PhotosLibraryService.shared
        clearStaleBroadcastState()
        startMonitoringBroadcast()
    }
    
    deinit {
        pollingTimer?.invalidate()
    }
    
    // MARK: - Broadcast monitoring + ledger polling

    private func clearStaleBroadcastState() {
        guard let defaults = UserDefaults(suiteName: groupID) else { return }
        // A host-app restart must not treat a previous extension session as a
        // newly completed broadcast. SampleHandler writes a fresh UUID per run.
        defaults.set(false, forKey: "broadcastActive")
        defaults.set(false, forKey: "broadcastFinished")
        defaults.removeObject(forKey: "broadcastSessionID")
        defaults.removeObject(forKey: "broadcastFinishedSessionID")
        defaults.removeObject(forKey: "broadcastVideoSampleCount")
        defaults.removeObject(forKey: "broadcastReceivedSampleCount")
        defaults.removeObject(forKey: "broadcastVideoBufferCount")
        defaults.removeObject(forKey: "broadcastVideoFormat")
        defaults.removeObject(forKey: "broadcastWriterStatus")
        defaults.removeObject(forKey: "broadcastWriterError")
        defaults.removeObject(forKey: "broadcastWriterErrorDomain")
        defaults.removeObject(forKey: "broadcastWriterErrorCode")
        defaults.synchronize()
    }
    
    private func startMonitoringBroadcast() {
        // Poll RPScreenRecorder status to detect when user starts/stops system-wide broadcast
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let defaults = UserDefaults(suiteName: self.groupID)
                let extensionActive = defaults?.bool(forKey: "broadcastActive") == true
                // This screen is driven by the Broadcast Upload Extension marker.
                // RPScreenRecorder.isRecording describes in-app capture and can be
                // stale/true during a system broadcast, causing false finalization.
                if extensionActive && !self.isBroadcasting {
                    self.isBroadcasting = true
                    self.extensionWasActive = true
                    self.activeBroadcastSessionID = defaults?.string(forKey: "broadcastSessionID")
                    self.lastSessionID = self.activeBroadcastSessionID
                    self.startTime = Date()
                    self.records.removeAll()
                    self.lastVideoURL = nil
                    self.lastSessionSize = 0
                    self.photosSaveMessage = nil
                    // Clear stale finished marker from any previous broadcast session
                    defaults?.set(false, forKey: "broadcastFinished")
                    defaults?.synchronize()
                } else if self.isBroadcasting && self.extensionWasActive && !extensionActive {
                    self.isBroadcasting = false
                    self.extensionWasActive = false
                    if let start = self.startTime {
                        self.lastSessionDuration = Date().timeIntervalSince(start)
                    } else {
                        self.lastSessionDuration = 0
                    }

                    // The extension finishes AVAssetWriter asynchronously after ReplayKit
                    // reports that recording has stopped. Wait for its completion marker
                    // before reading or exporting the file.
                    Task { @MainActor in
                        await self.finalizeBroadcastOutput()
                    }
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
        let decryptionKey = try? keychainService.getSymmetricKey()
        
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
            
            let sessionID = entry["sessionID"] as? String ?? activeBroadcastSessionID ?? "SampleHandler"

            // Decrypt the thumbnail only when loading it for the in-memory ledger.
            var thumbnail: UIImage?
            if let key = decryptionKey ?? nil,
               let data = try? EncryptedFrameStore.shared.decryptThumbnail(
                    sessionID: sessionID,
                    frameIndex: index,
                    using: key
               ) {
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
                sessionID: sessionID,
                resolution: resolution
            )
            newRecords.append(record)
        }
        
        // Keep sorted and capped at 20
        newRecords.sort { $0.index < $1.index }
        if newRecords.count > 20 { newRecords = Array(newRecords.suffix(20)) }
        records = newRecords
    }

    /// Wait for the Broadcast Upload Extension to finish its App Group MP4, then make an
    /// explicit Photos-library copy. Broadcast extensions do not save captured samples to
    /// Photos automatically because they are separate processes from the host app.
    private func finalizeBroadcastOutput() async {
        let finishedKey = "broadcastFinished"
        let defaults = UserDefaults(suiteName: groupID)
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
        let fileURL = containerURL?
            .appendingPathComponent(outputDirectoryName, isDirectory: true)
            .appendingPathComponent("broadcast.mp4")

        print("🔵 [Finalize] containerURL = \(String(describing: containerURL))")
        print("🔵 [Finalize] fileURL = \(String(describing: fileURL))")

        // Wait up to 5 seconds for broadcastFinished signal AND file writing completion
        for i in 0..<20 {
            let isFinished = defaults?.bool(forKey: finishedKey) == true
            let fileExists = fileURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
            var fileSize: Int64 = 0
            if let fileURL, fileExists {
                let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                fileSize = attributes?[.size] as? Int64 ?? 0
            }
            print("🔵 [Finalize] poll \(i): isFinished=\(isFinished) fileExists=\(fileExists) fileSize=\(fileSize)")
            if isFinished && fileSize > 512 {
                print("🟢 [Finalize] File ready — breaking out of poll loop.")
                break
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        let fileExists = fileURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        let fileSize: Int64
        if let fileURL, fileExists,
           let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
            fileSize = attributes[.size] as? Int64 ?? 0
        } else {
            fileSize = 0
        }
        let isFinished = defaults?.bool(forKey: finishedKey) == true
        let finishedSessionID = defaults?.string(forKey: "broadcastFinishedSessionID")
        let sampleCount = defaults?.integer(forKey: "broadcastVideoSampleCount") ?? 0
        let receivedCount = defaults?.integer(forKey: "broadcastReceivedSampleCount") ?? 0
        let videoBufferCount = defaults?.integer(forKey: "broadcastVideoBufferCount") ?? 0
        let videoFormat = defaults?.string(forKey: "broadcastVideoFormat") ?? "unknown"
        let writerStatus = defaults?.integer(forKey: "broadcastWriterStatus")
        let writerError = defaults?.string(forKey: "broadcastWriterError")
        let writerErrorDomain = defaults?.string(forKey: "broadcastWriterErrorDomain")
        let writerErrorCode = defaults?.integer(forKey: "broadcastWriterErrorCode")
        let errorText = writerError ?? "none"
        let errorDomain = writerErrorDomain ?? "none"
        print("🔵 [Finalize] Final state: fileExists=\(fileExists) fileSize=\(fileSize) broadcastFinished=\(isFinished)")
        print("🔵 [Finalize] receivedSamples=\(receivedCount) videoBuffers=\(videoBufferCount) writtenVideoSamples=\(sampleCount) format=\(videoFormat) writerStatus=\(String(describing: writerStatus)) writerError=\(errorText) domain=\(errorDomain) code=\(String(describing: writerErrorCode))")

        let sessionMatches = activeBroadcastSessionID != nil &&
            activeBroadcastSessionID == finishedSessionID

        if sessionMatches, let fileURL, fileExists, fileSize > 512 {
            print("🟢 [Finalize] Using REAL broadcast.mp4 — size=\(fileSize) bytes")
            do {
                try await photosLibraryService.saveVideo(at: fileURL)
                guard let key = try keychainService.getSymmetricKey() else {
                    throw NSError(
                        domain: "SystemWideBroadcast",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "The session encryption key is unavailable."]
                    )
                }

                let encryptedSize = try EncryptedFrameStore.shared.persistVideoFile(
                    at: fileURL,
                    sessionID: activeBroadcastSessionID ?? finishedSessionID ?? UUID().uuidString,
                    using: key
                )
                lastVideoURL = nil
                lastSessionSize = encryptedSize
                photosSaveMessage = "Broadcast saved to Photos and encrypted locally."
            } catch {
                lastVideoURL = fileURL
                lastSessionSize = fileSize
                photosSaveMessage = "Broadcast saved to App Group buffer."
            }
        } else {
            print("🔴 [Finalize] REAL RECORDING UNAVAILABLE — sessionMatches=\(sessionMatches), broadcast.mp4 missing or too small. fileExists=\(fileExists) size=\(fileSize) broadcastFinished=\(isFinished)")
#if targetEnvironment(simulator)
            // ReplayKit system-wide capture is unavailable in the simulator, so retain
            // the animated test artifact there. A physical device must never hide a
            // handler/writer failure behind this generated video.
            let sampleURL = createSampleVideoFile()
            lastVideoURL = sampleURL
            if let sampleURL {
                let attributes = try? FileManager.default.attributesOfItem(atPath: sampleURL.path)
                lastSessionSize = attributes?[.size] as? Int64 ?? 0
            }
            photosSaveMessage = "Simulator fallback video generated."
#else
            lastVideoURL = nil
            lastSessionSize = 0
            photosSaveMessage = writerError.map {
                "Device recording failed: \($0)"
            } ?? "Device recording was not produced. Check the BroadcastExtension console."
#endif
        }

        loadFrameMetadata()
        showSummary = true
    }
    // MARK: - Actions
    
    public func deleteLocalBuffer() {
        if let url = lastVideoURL {
            try? FileManager.default.removeItem(at: url)
        }
        if let sessionID = lastSessionID {
            try? EncryptedFrameStore.shared.deleteSession(sessionID)
        }
        UserDefaults(suiteName: groupID)?.removeObject(forKey: "frameMetadata")
        lastVideoURL = nil
        lastSessionSize = 0
        lastSessionID = nil
    }
    
    public func simulateBroadcastEnded() {
        self.lastSessionDuration = 125 // 2 min 5 seconds
        if self.lastVideoURL == nil || !FileManager.default.fileExists(atPath: self.lastVideoURL!.path) {
            self.lastVideoURL = createSampleVideoFile()
            if let url = self.lastVideoURL {
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                self.lastSessionSize = attributes?[.size] as? Int64 ?? 0
            }
        }
        self.showMockSummary = true
    }

    private func createSampleVideoFile() -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("broadcast_\(UUID().uuidString).mp4")
        guard let writer = try? AVAssetWriter(url: tempURL, fileType: .mp4) else { return nil }
        
        let width = 640
        let height = 480
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )
        
        guard writer.canAdd(writerInput) else { return nil }
        writer.add(writerInput)
        
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        var pxBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ] as CFDictionary,
            &pxBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pxBuffer else { return nil }
        
        // Generate frames matching actual session duration @ 30 FPS (fallback mode)
        let duration = max(3.0, min(lastSessionDuration > 0 ? lastSessionDuration : 5.0, 30.0))
        let fps = 30
        let totalFrames = Int(duration * Double(fps))
        
        for i in 0..<totalFrames {
            CVPixelBufferLockBaseAddress(buffer, [])
            if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
                let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                if let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
                ) {
                    // Animated gradient background
                    let progress = CGFloat(i) / CGFloat(totalFrames)
                    let r = 0.2 + 0.6 * sin(progress * .pi * 2)
                    let g = 0.4 + 0.4 * cos(progress * .pi * 2)
                    let b = 0.8
                    
                    context.setFillColor(red: r, green: g, blue: b, alpha: 1.0)
                    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                    
                    // Draw a visual center card
                    context.setFillColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9)
                    context.addPath(CGPath(roundedRect: CGRect(x: 80, y: 140, width: 480, height: 200), cornerWidth: 20, cornerHeight: 20, transform: nil))
                    context.fillPath()
                    
                    // Draw animated progress bar
                    context.setFillColor(red: 0.1, green: 0.6, blue: 0.3, alpha: 1.0)
                    let barWidth = 440.0 * progress
                    context.addPath(CGPath(roundedRect: CGRect(x: 100, y: 170, width: barWidth, height: 24), cornerWidth: 12, cornerHeight: 12, transform: nil))
                    context.fillPath()
                }
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            
            let presentTime = CMTime(value: Int64(i), timescale: Int32(fps))
            while !writerInput.isReadyForMoreMediaData {
                usleep(500)
            }
            adaptor.append(buffer, withPresentationTime: presentTime)
        }
        
        writerInput.markAsFinished()
        let group = DispatchGroup()
        group.enter()
        writer.finishWriting {
            group.leave()
        }
        group.wait()
        
        return tempURL
    }
    
    public func authenticateAndPrepareKeys() {
        errorMessage = nil
#if targetEnvironment(simulator)
        // Secure Enclave and biometric evaluation are unavailable on Simulator.
        // Use software test keys so the rest of the broadcast UI can be exercised.
        prepareKeys()
        return
#endif
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
#if !targetEnvironment(simulator)
            // Generate Enclave Key Pair (or fallback)
            try keychainService.generateSecureEnclaveKey()
#endif
            
            // Create or fetch symmetric key
            _ = try keychainService.getOrCreateSymmetricKey()
            
#if targetEnvironment(simulator)
            self.keyStatus = "Simulator Test Keys Active (Software)"
#else
            self.keyStatus = "Secure Keys Active (App Group Shared)"
#endif
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

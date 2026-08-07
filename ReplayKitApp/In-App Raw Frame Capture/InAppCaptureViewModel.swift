import Foundation
import Combine
import ReplayKit
import CryptoKit
import LocalAuthentication
import AVFoundation

@MainActor
public class InAppCaptureViewModel: ObservableObject {
    @Published public var isCapturing = false
    @Published public var frameCount = 0
    @Published public var lastEncryptedSize = 0
    @Published public var errorMessage: String?
    
    @Published public var isAuthenticated = false
    @Published public var keyStatus = "Keys Not Prepared"
    @Published public var showSummary = false
    @Published public var lastSessionDuration: TimeInterval = 0
    @Published public var lastSessionSize: Int64 = 0
    
    public var lastVideoURL: URL?
    
    private let recorderService: ScreenRecorderServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var symmetricKey: SymmetricKey?
    
    private var startTime: Date?
    private var accumulatedSize: Int64 = 0
    
    // Video writing variables
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var currentVideoURL: URL?
    private let writerQueue = DispatchQueue(label: "com.apkia.replaykitapp.writer-queue")
    private var hasStartedSession = false
    
    public init(
        recorderService: ScreenRecorderServiceProtocol = ReplayKitScreenRecorderService.shared,
        keychainService: KeychainServiceProtocol = SharedKeychainManager.shared
    ) {
        self.recorderService = recorderService
        self.keychainService = keychainService
        
        recorderService.isCapturingPublisher
            .receive(on: RunLoop.main)
            .assign(to: \.isCapturing, on: self)
            .store(in: &cancellables)
    }
    
    public func authenticateAndPrepareKeys() {
        errorMessage = nil
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            self.prepareKeys()
            return
        }
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to generate hardware-bound secure capture keys.") { success, authError in
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
            try keychainService.generateSecureEnclaveKey()
            _ = try keychainService.getOrCreateSymmetricKey()
            self.keyStatus = "Secure Keys Active (Secure Enclave Bound)"
            self.isAuthenticated = true
        } catch {
            self.errorMessage = "Failed to generate keys: \(error.localizedDescription)"
        }
    }
    
    public func startCapture() {
        guard isAuthenticated else {
            errorMessage = "Please authenticate first to setup Secure Enclave keys."
            return
        }
        
        errorMessage = nil
        frameCount = 0
        lastEncryptedSize = 0
        accumulatedSize = 0
        hasStartedSession = false
        startTime = Date()
        
        // Prepare file URL for writing
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("capture_\(UUID().uuidString).mp4")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        currentVideoURL = fileURL
        lastVideoURL = nil
        
        do {
            let writer = try AVAssetWriter(url: fileURL, fileType: .mp4)
            assetWriter = writer
        } catch {
            errorMessage = "Asset writer setup failed: \(error.localizedDescription)"
            return
        }
        
        Task {
            do {
                self.symmetricKey = try keychainService.getOrCreateSymmetricKey()
                
                try await recorderService.startCapture { [weak self] sampleBuffer, bufferType in
                    guard let self = self, bufferType == .video else { return }
                    
                    autoreleasepool {
                        self.processAndEncryptFrame(sampleBuffer)
                        self.appendFrameToAssetWriter(sampleBuffer)
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    public func stopCapture() {
        Task {
            do {
                try await recorderService.stopCapture()
                
                if let start = startTime {
                    lastSessionDuration = Date().timeIntervalSince(start)
                } else {
                    lastSessionDuration = 0
                }
                
                // Finalize the video asset writing
                await finalizeVideoWriting()
                
                showSummary = true
            } catch {
                errorMessage = error.localizedDescription
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
    
    private func appendFrameToAssetWriter(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let writer = assetWriter else { return }
        
        writerQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Lazy initialization of input because we need the dimensions from the imageBuffer
            if self.assetWriterInput == nil {
                let width = CVPixelBufferGetWidth(imageBuffer)
                let height = CVPixelBufferGetHeight(imageBuffer)
                
                let outputSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: width,
                    AVVideoHeightKey: height
                ]
                
                let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
                input.expectsMediaDataInRealTime = true
                
                if writer.canAdd(input) {
                    writer.add(input)
                    self.assetWriterInput = input
                } else {
                    print("Could not add AVAssetWriterInput to writer.")
                    return
                }
            }
            
            guard let input = self.assetWriterInput else { return }
            
            if writer.status == .unknown {
                writer.startWriting()
                writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                self.hasStartedSession = true
            }
            
            if writer.status == .writing && input.isReadyForMoreMediaData && self.hasStartedSession {
                input.append(sampleBuffer)
            }
        }
    }
    
    private func finalizeVideoWriting() async {
        await withCheckedContinuation { continuation in
            writerQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                self.assetWriterInput?.markAsFinished()
                
                if let writer = self.assetWriter, writer.status == .writing {
                    writer.finishWriting { [weak self] in
                        guard let self = self else {
                            continuation.resume()
                            return
                        }
                        
                        if let url = self.currentVideoURL {
                            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                            let fileSize = attributes?[.size] as? Int64 ?? 0
                            
                            DispatchQueue.main.async {
                                self.lastVideoURL = url
                                self.lastSessionSize = fileSize
                            }
                        }
                        continuation.resume()
                    }
                } else {
                    continuation.resume()
                }
            }
        }
        
        // Reset properties
        self.assetWriter = nil
        self.assetWriterInput = nil
        self.currentVideoURL = nil
    }
    
    private func processAndEncryptFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        
        guard let jpegData = context.jpegRepresentation(of: ciImage, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:]) else { return }
        
        guard let key = self.symmetricKey else { return }
        
        do {
            let sealedBox = try AES.GCM.seal(jpegData, using: key)
            let payload = sealedBox.combined
            let payloadSize = payload?.count ?? 0
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.frameCount += 1
                self.lastEncryptedSize = payloadSize
                self.accumulatedSize += Int64(payloadSize)
            }
        } catch {
            print("Frame encryption failed: \(error)")
        }
    }
}


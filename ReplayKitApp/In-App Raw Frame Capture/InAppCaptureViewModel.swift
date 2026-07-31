import Foundation
import Combine
import ReplayKit
import CryptoKit

@MainActor
public class InAppCaptureViewModel: ObservableObject {
    @Published public var isCapturing = false
    @Published public var frameCount = 0
    @Published public var lastEncryptedSize = 0
    @Published public var errorMessage: String?
    
    private let recorderService: ScreenRecorderServiceProtocol
    private let keychainService: KeychainServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var symmetricKey: SymmetricKey?
    
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
    
    public func startCapture() {
        errorMessage = nil
        frameCount = 0
        lastEncryptedSize = 0
        
        Task {
            do {
                // 1. Get or create symmetric key
                self.symmetricKey = try keychainService.getOrCreateSymmetricKey()
                
                // 2. Start ReplayKit frame capture
                try await recorderService.startCapture { [weak self] sampleBuffer, bufferType in
                    guard let self = self, bufferType == .video else { return }
                    
                    // Memory optimization: execute block within autoreleasepool
                    autoreleasepool {
                        self.processAndEncryptFrame(sampleBuffer)
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
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func processAndEncryptFrame(_ sampleBuffer: CMSampleBuffer) {
        // Extract raw image buffer
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Convert frame using CPU memory optimization
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext(options: [.useSoftwareRenderer: false]) // leverage GPU
        
        guard let jpegData = context.jpegRepresentation(of: ciImage, colorSpace: CGColorSpaceCreateDeviceRGB(), options: [:]) else { return }
        
        guard let key = self.symmetricKey else { return }
        
        do {
            // High-performance hardware symmetric encryption
            let sealedBox = try AES.GCM.seal(jpegData, using: key)
            let payload = sealedBox.combined
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.frameCount += 1
                self.lastEncryptedSize = payload?.count ?? 0
            }
        } catch {
            print("Frame encryption failed: \(error)")
        }
    }
}

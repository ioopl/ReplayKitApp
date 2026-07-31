import Foundation
import ReplayKit
import Combine

public class ReplayKitScreenRecorderService: NSObject, ScreenRecorderServiceProtocol {
    public static let shared = ReplayKitScreenRecorderService()
    
    private let recorder = RPScreenRecorder.shared()
    
    @Published private var _isRecording = false
    @Published private var _isCapturing = false
    @Published private var _isClipBuffering = false
    
    public var isRecording: Bool { _isRecording }
    public var isCapturing: Bool { _isCapturing }
    public var isClipBuffering: Bool { _isClipBuffering }
    
    public var isRecordingPublisher: Published<Bool>.Publisher { $_isRecording }
    public var isCapturingPublisher: Published<Bool>.Publisher { $_isCapturing }
    public var isClipBufferingPublisher: Published<Bool>.Publisher { $_isClipBuffering }
    
    private override init() {
        super.init()
    }
    
    @MainActor
    public func startRecording() async throws {
        guard recorder.isAvailable else {
            throw NSError(domain: "ScreenRecorderService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Screen recorder is unavailable."])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            recorder.startRecording { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    self._isRecording = true
                    continuation.resume()
                }
            }
        }
    }
    
    @MainActor
    public func stopRecording() async throws -> RPPreviewViewController? {
        return try await withCheckedThrowingContinuation { continuation in
            recorder.stopRecording { previewViewController, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    self._isRecording = false
                    continuation.resume(returning: previewViewController)
                }
            }
        }
    }
    
    @MainActor
    public func startCapture(onFrame: @escaping (CMSampleBuffer, RPSampleBufferType) -> Void) async throws {
        guard recorder.isAvailable else {
            throw NSError(domain: "ScreenRecorderService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Screen recorder is unavailable."])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            recorder.startCapture(handler: { sampleBuffer, sampleBufferType, error in
                if let error = error {
                    print("Capture frame error: \(error)")
                    return
                }
                onFrame(sampleBuffer, sampleBufferType)
            }, completionHandler: { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    self._isCapturing = true
                    continuation.resume()
                }
            })
        }
    }
    
    @MainActor
    public func stopCapture() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            recorder.stopCapture { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    self._isCapturing = false
                    continuation.resume()
                }
            }
        }
    }
    
    @MainActor
    public func startClipBuffering() async throws {
        guard recorder.isAvailable else {
            throw NSError(domain: "ScreenRecorderService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Screen recorder is unavailable."])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            recorder.startClipBuffering { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    self._isClipBuffering = true
                    continuation.resume()
                }
            }
        }
    }
    
    @MainActor
    public func exportClip(clipDuration: TimeInterval) async throws -> URL {
        let tempDirectory = FileManager.default.temporaryDirectory
        let outputURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        
        return try await withCheckedThrowingContinuation { continuation in
            recorder.exportClip(to: outputURL, duration: clipDuration) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: outputURL)
                }
            }
        }
    }
    
    @MainActor
    public func stopClipBuffering() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            recorder.stopClipBuffering { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    self._isClipBuffering = false
                    continuation.resume()
                }
            }
        }
    }
}

import Combine
import ReplayKit
import CryptoKit
@testable import ReplayKitApp

// MARK: - Mocks

class MockScreenRecorderService: ScreenRecorderServiceProtocol {
    var isRecording = false
    var isCapturing = false
    var isClipBuffering = false
    
    @Published private var _isRecording = false
    @Published private var _isCapturing = false
    @Published private var _isClipBuffering = false
    
    var isRecordingPublisher: Published<Bool>.Publisher { $_isRecording }
    var isCapturingPublisher: Published<Bool>.Publisher { $_isCapturing }
    var isClipBufferingPublisher: Published<Bool>.Publisher { $_isClipBuffering }
    
    var shouldFail = false
    var captureFrameHandler: ((CMSampleBuffer, RPSampleBufferType) -> Void)?
    
    func startRecording() async throws {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"])
        }
        _isRecording = true
        isRecording = true
    }
    
    func stopRecording() async throws -> RPPreviewViewController? {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to stop recording"])
        }
        _isRecording = false
        isRecording = false
        return nil
    }
    
    func startCapture(onFrame: @escaping (CMSampleBuffer, RPSampleBufferType) -> Void) async throws {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start capture"])
        }
        _isCapturing = true
        isCapturing = true
        captureFrameHandler = onFrame
    }
    
    func stopCapture() async throws {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to stop capture"])
        }
        _isCapturing = false
        isCapturing = false
    }
    
    func startClipBuffering() async throws {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to start clip buffering"])
        }
        _isClipBuffering = true
        isClipBuffering = true
    }
    
    func exportClip(clipDuration: TimeInterval) async throws -> URL {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to export clip"])
        }
        return URL(fileURLWithPath: "/tmp/mock_clip.mp4")
    }
    
    func stopClipBuffering() async throws {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to stop clip buffering"])
        }
        _isClipBuffering = false
        isClipBuffering = false
    }
}

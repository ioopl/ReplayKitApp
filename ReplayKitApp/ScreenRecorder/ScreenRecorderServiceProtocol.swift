import Combine
import ReplayKit

public protocol ScreenRecorderServiceProtocol: AnyObject {
    var isRecording: Bool { get }
    var isCapturing: Bool { get }
    var isClipBuffering: Bool { get }
    
    var isRecordingPublisher: Published<Bool>.Publisher { get }
    var isCapturingPublisher: Published<Bool>.Publisher { get }
    var isClipBufferingPublisher: Published<Bool>.Publisher { get }
    
    func startRecording() async throws
    func stopRecording() async throws -> RPPreviewViewController?
    
    func startCapture(onFrame: @escaping (CMSampleBuffer, RPSampleBufferType) -> Void) async throws
    func stopCapture() async throws
    
    func startClipBuffering() async throws
    func exportClip(clipDuration: TimeInterval) async throws -> URL
    func stopClipBuffering() async throws
}

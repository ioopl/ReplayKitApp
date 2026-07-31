import Foundation
import Combine
import ReplayKit

@MainActor
public class InAppRecordingViewModel: ObservableObject {
    @Published public var isRecording = false
    @Published public var errorMessage: String?
    @Published public var previewController: RPPreviewViewController?
    
    private let recorderService: ScreenRecorderServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    public init(recorderService: ScreenRecorderServiceProtocol = ReplayKitScreenRecorderService.shared) {
        self.recorderService = recorderService
        
        recorderService.isRecordingPublisher
            .receive(on: RunLoop.main)
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)
    }
    
    public func startRecording() {
        errorMessage = nil
        Task {
            do {
                try await recorderService.startRecording()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    public func stopRecording() {
        errorMessage = nil
        Task {
            do {
                let controller = try await recorderService.stopRecording()
                self.previewController = controller
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

import Foundation
import Combine
import ReplayKit

@MainActor
public class InAppClipsViewModel: ObservableObject {
    @Published public var isClipBuffering = false
    @Published public var lastExportedClipURL: URL?
    @Published public var errorMessage: String?
    @Published public var isExporting = false
    
    private let recorderService: ScreenRecorderServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    public init(recorderService: ScreenRecorderServiceProtocol = ReplayKitScreenRecorderService.shared) {
        self.recorderService = recorderService
        
        recorderService.isClipBufferingPublisher
            .receive(on: RunLoop.main)
            .assign(to: \.isClipBuffering, on: self)
            .store(in: &cancellables)
    }
    
    public func startClipBuffering() {
        errorMessage = nil
        Task {
            do {
                try await recorderService.startClipBuffering()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    public func exportClip() {
        errorMessage = nil
        isExporting = true
        
        Task {
            do {
                // Export the last 15 seconds as a clip
                let url = try await recorderService.exportClip(clipDuration: 15.0)
                self.lastExportedClipURL = url
                self.isExporting = false
            } catch {
                errorMessage = error.localizedDescription
                self.isExporting = false
            }
        }
    }
    
    public func stopClipBuffering() {
        Task {
            do {
                try await recorderService.stopClipBuffering()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

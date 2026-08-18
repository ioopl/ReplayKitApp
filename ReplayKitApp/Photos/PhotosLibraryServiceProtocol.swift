import Foundation
import Photos


@MainActor
public protocol PhotosLibraryServiceProtocol: AnyObject {
    func saveVideo(at url: URL) async throws
}

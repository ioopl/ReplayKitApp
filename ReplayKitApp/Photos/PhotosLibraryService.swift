import Foundation
import Photos

public enum PhotosLibraryServiceError: LocalizedError {
    case accessDenied
    case unableToCreateAsset

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Photos access was not granted."
        case .unableToCreateAsset:
            return "The video could not be added to Photos."
        }
    }
}

@MainActor
public final class PhotosLibraryService: PhotosLibraryServiceProtocol {
    public static let shared = PhotosLibraryService()

    private init() {}

    public func saveVideo(at url: URL) async throws {
        let authorizationStatus = await requestAddOnlyAuthorization()
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw PhotosLibraryServiceError.accessDenied
        }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                guard PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url) != nil else {
                    return
                }
            }) { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? PhotosLibraryServiceError.unableToCreateAsset)
                }
            }
        }
    }

    private func requestAddOnlyAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
}

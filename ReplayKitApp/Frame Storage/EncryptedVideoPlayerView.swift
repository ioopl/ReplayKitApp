import SwiftUI
import AVKit
import CryptoKit

public struct EncryptedVideoPlayerView: View {
    let sessionID: String
    @State private var player: AVPlayer?
    @State private var temporaryURL: URL?
    @State private var errorMessage: String?

    public init(sessionID: String) { self.sessionID = sessionID }

    public var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else if let errorMessage {
                ContentUnavailableView("Playback unavailable", systemImage: "lock.trianglebadge.exclamationmark", description: Text(errorMessage))
            } else {
                ZStack {
                    Color.black
                    ProgressView("Decrypting securely…").tint(.white)
                }
            }
        }
        .task { await preparePlayback() }
        .onDisappear {
            player?.pause()
            player = nil
            if let temporaryURL { try? FileManager.default.removeItem(at: temporaryURL) }
            temporaryURL = nil
        }
    }

    @MainActor
    private func preparePlayback() async {
        do {
            guard let key = try SharedKeychainManager.shared.getSymmetricKey() else {
                throw NSError(domain: "EncryptedVideoPlayer", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "The session encryption key is unavailable."
                ])
            }

            let url = try EncryptedFrameStore.shared.decryptVideoToTemporaryFile(sessionID: sessionID, using: key)
            temporaryURL = url
            player = AVPlayer(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    EncryptedVideoPlayerView(sessionID: "12345")
}

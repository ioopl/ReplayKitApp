import SwiftUI
import UIKit
import CryptoKit

public struct EncryptedFrameGalleryView: View {
    let sessionID: String

    @State private var metadata: [StoredFrameMetadata] = []
    @State private var thumbnails: [Int: UIImage] = [:]
    @State private var selectedRecord: FrameRecord?
    @State private var errorMessage: String?
    @State private var isLoading = true

    public init(sessionID: String) {
        self.sessionID = sessionID
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Encrypted Frame Gallery", systemImage: "lock.rectangle.stack.fill")
                    .font(.headline)
                Spacer()
                Text("\(metadata.count)")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            if isLoading {
                ProgressView("Loading authenticated previews…")
                    .font(.caption)
                    .frame(maxWidth: .infinity, minHeight: 90)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if metadata.isEmpty {
                Text("No encrypted frame files were retained for this session.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                    ForEach(metadata) { item in
                        Button {
                            verifyAndOpen(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Group {
                                    if let image = thumbnails[item.index] {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } else {
                                        Image(systemName: "photo.badge.checkmark")
                                            .font(.title2)
                                            .foregroundColor(.secondary)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .background(Color.secondary.opacity(0.1))
                                    }
                                }
                                .frame(height: 72)
                                .clipped()
                                .cornerRadius(8)

                                Text("Frame #\(item.index)")
                                    .font(.caption.bold())
                                Text(item.timestamp)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
        .task {
            loadGallery()
        }
        .sheet(item: $selectedRecord) { record in
            FrameDetailView(record: record)
        }
    }

    private func loadGallery() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let key = try SharedKeychainManager.shared.getSymmetricKey() else {
                    throw NSError(domain: "EncryptedFrameGallery", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "The session encryption key is unavailable."
                    ])
                }
                let storedMetadata = try EncryptedFrameStore.shared.metadata(for: sessionID)
                var loadedThumbnails: [Int: UIImage] = [:]
                for item in storedMetadata {
                    if let data = try? EncryptedFrameStore.shared.decryptThumbnail(
                        sessionID: sessionID,
                        frameIndex: item.index,
                        using: key
                    ), let image = UIImage(data: data) {
                        loadedThumbnails[item.index] = image
                    }
                }
                DispatchQueue.main.async {
                    metadata = storedMetadata
                    thumbnails = loadedThumbnails
                    isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func verifyAndOpen(_ item: StoredFrameMetadata) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let key = try SharedKeychainManager.shared.getSymmetricKey() else {
                    throw NSError(domain: "EncryptedFrameGallery", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: "The session encryption key is unavailable."
                    ])
                }

                // Opening the sealed payload verifies its AES-GCM authentication tag.
                let payload = try EncryptedFrameStore.shared.decryptPayload(
                    sessionID: sessionID,
                    frameIndex: item.index,
                    using: key
                )
                let recomputedChain = SHA256.hash(data: Data((item.sha256 + item.previousHash).utf8))
                    .map { String(format: "%02x", $0) }
                    .joined()
                guard recomputedChain == item.chainHash else {
                    throw NSError(domain: "EncryptedFrameGallery", code: 3, userInfo: [
                        NSLocalizedDescriptionKey: "Frame chain verification failed."
                    ])
                }

                let thumbnailData = try EncryptedFrameStore.shared.decryptThumbnail(
                    sessionID: sessionID,
                    frameIndex: item.index,
                    using: key
                )
                guard let image = UIImage(data: payload) ?? UIImage(data: thumbnailData) else {
                    throw NSError(domain: "EncryptedFrameGallery", code: 4, userInfo: [
                        NSLocalizedDescriptionKey: "The authenticated preview could not be decoded."
                    ])
                }

                let record = FrameRecord(
                    id: UUID(),
                    index: item.index,
                    timestamp: item.timestamp,
                    sizeKB: item.sizeKB,
                    rawSize: item.rawSize,
                    sha256: item.sha256,
                    previousHash: item.previousHash,
                    chainHash: item.chainHash,
                    isChainValid: true,
                    isEncrypted: true,
                    thumbnail: image,
                    hexDump: payload.prefix(32).map { String(format: "%02X", $0) }.joined(separator: " "),
                    sessionID: item.sessionID,
                    resolution: item.resolution
                )
                DispatchQueue.main.async {
                    selectedRecord = record
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    EncryptedFrameGalleryView(sessionID: "String")
}

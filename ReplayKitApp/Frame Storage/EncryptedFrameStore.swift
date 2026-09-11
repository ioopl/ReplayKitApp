import Foundation
import CryptoKit
import Security

public struct StoredFrameMetadata: Codable, Identifiable, Sendable {
    public let index: Int
    public let timestamp: String
    public let sizeKB: String
    public let rawSize: Int
    public let sha256: String
    public let previousHash: String
    public let chainHash: String
    public let sessionID: String
    public let resolution: String

    public var id: String { "\(sessionID)-\(index)" }
}

/**
 `EncryptedFrameStore` writes to the App Group container returned by
 `containerURL(forSecurityApplicationGroupIdentifier:)`. This is still
 sandboxed storage: only the signed host app and its configured extension can
 access it. It is not publicly accessible like Photos or a web server.

 The frame payload and thumbnail files are encrypted with AES-GCM and written
 with iOS file-protection options. The symmetric key remains in the shared
 Keychain. This gives defense in depth: App Group sandboxing controls which
 processes can reach the files, while AES-GCM protects the bytes if the files
 are copied without the key.
 */
/// Stores encrypted frame evidence in the shared App Group container.
/// UserDefaults is intentionally used only for the broadcast's live ledger;
/// image bytes and encrypted payloads are kept as authenticated files here.
public final class EncryptedFrameStore {
    public static let shared = EncryptedFrameStore()
    public static let groupID = "group.com.apkia.replaykitapp.shared"

    private let fileManager = FileManager.default
    private let lock = NSLock()
    private let videoChunkSize = 1024 * 1024
    private let videoMagic = Data([0x45, 0x56, 0x4D, 0x31]) // EVM1

    private init() {}

    public func persist(
        payload: Data,
        thumbnail: Data?,
        metadata: StoredFrameMetadata,
        using key: SymmetricKey
    ) throws {
        lock.lock()
        defer { lock.unlock() }

        let directory = try sessionDirectory(for: metadata.sessionID, create: true)
        let payloadURL = directory.appendingPathComponent(payloadName(for: metadata.index))
        try seal(payload, using: key).write(to: payloadURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])

        if let thumbnail {
            let thumbnailURL = directory.appendingPathComponent(thumbnailName(for: metadata.index))
            try seal(thumbnail, using: key).write(to: thumbnailURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }

        var manifest = try loadManifestLocked(for: metadata.sessionID)
        manifest.removeAll { $0.index == metadata.index }
        manifest.append(metadata)
        manifest.sort { $0.index < $1.index }
        try writeManifestLocked(manifest, for: metadata.sessionID)
    }

    public func metadata(for sessionID: String) throws -> [StoredFrameMetadata] {
        lock.lock()
        defer { lock.unlock() }
        return try loadManifestLocked(for: sessionID)
    }

    /// Returns sessions whose encrypted evidence is still present after relaunch.
    public func availableSessionIDs() -> [String] {
        guard let container = try? sharedContainerURL() else { return [] }
        let root = container.appendingPathComponent("EncryptedFrames", isDirectory: true)
        return (try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]))?
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map(\.lastPathComponent) ?? []
    }

    public func decryptPayload(sessionID: String, frameIndex: Int, using key: SymmetricKey) throws -> Data {
        try decrypt(file: payloadURL(sessionID: sessionID, frameIndex: frameIndex), using: key)
    }

    public func decryptThumbnail(sessionID: String, frameIndex: Int, using key: SymmetricKey) throws -> Data {
        try decrypt(file: thumbnailURL(sessionID: sessionID, frameIndex: frameIndex), using: key)
    }

    /// Encrypts the completed AVAssetWriter output in authenticated chunks, then
    /// removes the plaintext writer output. AVPlayer cannot consume AES-GCM bytes
    /// directly, so playback uses `decryptVideoToTemporaryFile` on demand.
    public func persistVideoFile(at sourceURL: URL, sessionID: String, using key: SymmetricKey) throws -> Int64 {
        lock.lock()
        defer { lock.unlock() }

        let directory = try sessionDirectory(for: sessionID, create: true)
        let encryptedURL = directory.appendingPathComponent("recording.mp4.enc")
        FileManager.default.createFile(atPath: encryptedURL.path, contents: nil)
        let input = try FileHandle(forReadingFrom: sourceURL)
        let output = try FileHandle(forWritingTo: encryptedURL)
        defer { try? input.close(); try? output.close() }

        try output.write(contentsOf: videoMagic)
        while let chunk = try input.read(upToCount: videoChunkSize), !chunk.isEmpty {
            let combined = try seal(chunk, using: key)
            var length = UInt64(combined.count).bigEndian
            try output.write(contentsOf: Data(bytes: &length, count: MemoryLayout<UInt64>.size))
            try output.write(contentsOf: combined)
        }
        try output.synchronize()
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: encryptedURL.path
        )
        try FileManager.default.removeItem(at: sourceURL)
        return (try FileManager.default.attributesOfItem(atPath: encryptedURL.path)[.size] as? NSNumber)?.int64Value ?? 0
    }

    public func hasEncryptedVideo(sessionID: String) -> Bool {
        guard let url = try? encryptedVideoURL(for: sessionID) else { return false }
        return fileManager.fileExists(atPath: url.path)
    }

    /// Produces a protected, temporary plaintext URL for AVPlayer. The caller
    /// must delete the returned file when the player disappears.
    public func decryptVideoToTemporaryFile(sessionID: String, using key: SymmetricKey) throws -> URL {
        lock.lock()
        defer { lock.unlock() }

        let encryptedURL = try encryptedVideoURL(for: sessionID)
        let input = try FileHandle(forReadingFrom: encryptedURL)
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent("playback_\(UUID().uuidString).mp4")
        fileManager.createFile(atPath: tempURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: tempURL)
        defer { try? input.close(); try? output.close() }

        guard try input.read(upToCount: videoMagic.count) == videoMagic else {
            throw NSError(domain: "EncryptedFrameStore", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unsupported encrypted video format."])
        }
        while let lengthData = try input.read(upToCount: MemoryLayout<UInt64>.size), lengthData.count == MemoryLayout<UInt64>.size {
            let length = lengthData.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
            guard length > 0, length <= 8 * 1024 * 1024 else {
                throw NSError(domain: "EncryptedFrameStore", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid encrypted video chunk."])
            }
            let combined = try input.readExactly(Int(length))
            try output.write(contentsOf: try AES.GCM.open(try AES.GCM.SealedBox(combined: combined), using: key))
        }
        try output.synchronize()
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: tempURL.path
        )
        return tempURL
    }

    public func deleteEncryptedVideo(sessionID: String) throws {
        let url = try encryptedVideoURL(for: sessionID)
        if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
    }

    public func deleteSession(_ sessionID: String) throws {
        lock.lock()
        defer { lock.unlock() }
        let directory = try sessionDirectory(for: sessionID, create: false)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
    }

    private func seal(_ data: Data, using key: SymmetricKey) throws -> Data {
        try AES.GCM.seal(data, using: key).combined ?? Data()
    }

    private func decrypt(file: URL, using key: SymmetricKey) throws -> Data {
        let combined = try Data(contentsOf: file)
        return try AES.GCM.open(try AES.GCM.SealedBox(combined: combined), using: key)
    }

    private func sessionDirectory(for sessionID: String, create: Bool) throws -> URL {
        let container = try sharedContainerURL()
        let safeID = sessionID.replacingOccurrences(of: "/", with: "_")
        let directory = container.appendingPathComponent("EncryptedFrames", isDirectory: true)
            .appendingPathComponent(safeID, isDirectory: true)
        if create {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func sharedContainerURL() throws -> URL {
        guard let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.groupID) else {
            throw NSError(domain: "EncryptedFrameStore", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Shared App Group container is unavailable."
            ])
        }
        return container
    }

    private func manifestURL(for sessionID: String) throws -> URL {
        try sessionDirectory(for: sessionID, create: false).appendingPathComponent("manifest.json")
    }

    private func payloadURL(sessionID: String, frameIndex: Int) throws -> URL {
        try sessionDirectory(for: sessionID, create: false).appendingPathComponent(payloadName(for: frameIndex))
    }

    private func thumbnailURL(sessionID: String, frameIndex: Int) throws -> URL {
        try sessionDirectory(for: sessionID, create: false).appendingPathComponent(thumbnailName(for: frameIndex))
    }

    private func encryptedVideoURL(for sessionID: String) throws -> URL {
        try sessionDirectory(for: sessionID, create: false).appendingPathComponent("recording.mp4.enc")
    }

    private func payloadName(for index: Int) -> String { String(format: "frame_%08d.bin", index) }
    private func thumbnailName(for index: Int) -> String { String(format: "thumb_%08d.bin", index) }

    private func loadManifestLocked(for sessionID: String) throws -> [StoredFrameMetadata] {
        let url = try manifestURL(for: sessionID)
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([StoredFrameMetadata].self, from: Data(contentsOf: url))
    }

    private func writeManifestLocked(_ manifest: [StoredFrameMetadata], for sessionID: String) throws {
        let directory = try sessionDirectory(for: sessionID, create: true)
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: directory.appendingPathComponent("manifest.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

private extension FileHandle {
    func readExactly(_ count: Int) throws -> Data {
        var result = Data()
        while result.count < count {
            guard let part = try read(upToCount: count - result.count), !part.isEmpty else {
                throw NSError(domain: "EncryptedFrameStore", code: 6, userInfo: [NSLocalizedDescriptionKey: "Unexpected end of encrypted video."])
            }
            result.append(part)
        }
        return result
    }
}

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

/// Stores encrypted frame evidence in the shared App Group container.
/// UserDefaults is intentionally used only for the broadcast's live ledger;
/// image bytes and encrypted payloads are kept as authenticated files here.
public final class EncryptedFrameStore {
    public static let shared = EncryptedFrameStore()
    public static let groupID = "group.com.apkia.replaykitapp.shared"

    private let fileManager = FileManager.default
    private let lock = NSLock()

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

    public func decryptPayload(sessionID: String, frameIndex: Int, using key: SymmetricKey) throws -> Data {
        try decrypt(file: payloadURL(sessionID: sessionID, frameIndex: frameIndex), using: key)
    }

    public func decryptThumbnail(sessionID: String, frameIndex: Int, using key: SymmetricKey) throws -> Data {
        try decrypt(file: thumbnailURL(sessionID: sessionID, frameIndex: frameIndex), using: key)
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
        guard let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.groupID) else {
            throw NSError(domain: "EncryptedFrameStore", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Shared App Group container is unavailable."
            ])
        }
        let safeID = sessionID.replacingOccurrences(of: "/", with: "_")
        let directory = container.appendingPathComponent("EncryptedFrames", isDirectory: true)
            .appendingPathComponent(safeID, isDirectory: true)
        if create {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
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

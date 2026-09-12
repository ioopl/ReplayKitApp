import Foundation
import SwiftData

/// The durable recording/document row.  `userID` is an app-level identity;
/// the Secure Enclave key fingerprint is stored separately because it identifies
/// the signing/encryption key, not a human user.
@Model
public final class RecordingDocumentEntity {
    @Attribute(.unique) public var id: UUID
    @Attribute(.unique) public var sessionID: String
    public var title: String
    public var userID: String
    public var createdAt: Date
    public var duration: Double
    public var encryptedVideoName: String?
    public var videoSize: Int64
    public var frameCount: Int
    public var keyFingerprint: String
    public var cryptographicTimestamp: String
    public var finalChainHash: String
    public var persistenceStatus: String
    public var validationMessage: String

    @Relationship(deleteRule: .cascade, inverse: \FrameEntity.document)
    public var frames: [FrameEntity] = []

    public init(sessionID: String, userID: String, createdAt: Date = .now) {
        self.id = UUID()
        self.sessionID = sessionID
        self.title = "Recording \(Self.displayDate.string(from: createdAt))"
        self.userID = userID
        self.createdAt = createdAt
        self.duration = 0
        self.encryptedVideoName = nil
        self.videoSize = 0
        self.frameCount = 0
        self.keyFingerprint = "Unavailable"
        self.cryptographicTimestamp = "Unavailable"
        self.finalChainHash = "Unavailable"
        self.persistenceStatus = "pending"
        self.validationMessage = "Waiting for encrypted artifacts."
    }

    private static let displayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

@Model
public final class FrameEntity {
    @Attribute(.unique) public var id: UUID
    public var documentID: UUID
    public var frameIndex: Int
    public var timestamp: String
    public var sizeKB: String
    public var rawSize: Int
    public var sha256: String
    public var previousHash: String
    public var chainHash: String
    public var resolution: String
    public var payloadFileName: String
    public var thumbnailFileName: String
    public var validationStatus: String

    public var document: RecordingDocumentEntity?

    public init(document: RecordingDocumentEntity, metadata: StoredFrameMetadata) {
        self.id = UUID()
        self.documentID = document.id
        self.frameIndex = metadata.index
        self.timestamp = metadata.timestamp
        self.sizeKB = metadata.sizeKB
        self.rawSize = metadata.rawSize
        self.sha256 = metadata.sha256
        self.previousHash = metadata.previousHash
        self.chainHash = metadata.chainHash
        self.resolution = metadata.resolution
        self.payloadFileName = String(format: "frame_%08d.bin", metadata.index)
        self.thumbnailFileName = String(format: "thumb_%08d.bin", metadata.index)
        self.validationStatus = "stored"
        self.document = document
    }
}

@MainActor
public enum RecordingPersistence {
    public static func importSession(
        sessionID: String,
        duration: TimeInterval,
        finalChainHash: String,
        cryptographicTimestamp: String,
        keyFingerprint: String,
        videoSize: Int64,
        context: ModelContext
    ) throws {
        let descriptor = FetchDescriptor<RecordingDocumentEntity>(
            predicate: #Predicate { $0.sessionID == sessionID }
        )
        let existingDocument = try context.fetch(descriptor).first
        let document = existingDocument ?? RecordingDocumentEntity(
            sessionID: sessionID,
            userID: LocalUserIdentity.current
        )
        if existingDocument == nil { context.insert(document) }

        document.duration = duration
        document.finalChainHash = finalChainHash
        document.cryptographicTimestamp = cryptographicTimestamp
        document.keyFingerprint = keyFingerprint
        document.videoSize = videoSize
        document.encryptedVideoName = EncryptedFrameStore.shared.hasEncryptedVideo(sessionID: sessionID)
            ? "recording.mp4.enc"
            : nil

        let storedFrames = try EncryptedFrameStore.shared.metadata(for: sessionID)
        let existing = Set(document.frames.map(\.frameIndex))
        for metadata in storedFrames where !existing.contains(metadata.index) {
            context.insert(FrameEntity(document: document, metadata: metadata))
        }
        document.frameCount = storedFrames.count
        document.persistenceStatus = storedFrames.isEmpty ? "needsAttention" : "verified"
        document.validationMessage = storedFrames.isEmpty
            ? "No encrypted frame manifest was found."
            : "SwiftData catalog and encrypted frame manifest are present."
        try context.save()
    }
}

public enum LocalUserIdentity {
    private static let key = "local.app.user.id"

    public static var current: String {
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: key)
        return value
    }
}

import SwiftUI

public struct FrameRecord: Identifiable, Sendable {
    public let id: UUID
    public let index: Int
    public let timestamp: String
    public let sizeKB: String
    public let rawSize: Int
    public let sha256: String
    public let previousHash: String
    public let chainHash: String
    public let isChainValid: Bool
    public let isEncrypted: Bool
    public let thumbnail: UIImage?
    public let hexDump: String
    public let sessionID: String
    public let resolution: String
}

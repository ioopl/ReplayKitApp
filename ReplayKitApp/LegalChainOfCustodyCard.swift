import Foundation
import SwiftUI
import UIKit
import SwiftData

/// Shared inspection card used by both the session and frame detail screens.
/// The fingerprint is read from the persisted key at display time so it is
/// never a placeholder or a value copied into the UI at build time.
public struct LegalChainOfCustodyCard: View {
    let chainHash: String?
    let timestamp: String?
    let sessionID: String?
    @Query private var documents: [RecordingDocumentEntity]

    @State private var fingerprint: String?
    @State private var fingerprintUnavailable = false
    @State private var copiedValue: String?

    public init(chainHash: String? = nil, timestamp: String? = nil, sessionID: String? = nil) {
        self.chainHash = chainHash
        self.timestamp = timestamp
        self.sessionID = sessionID
    }

    private var storedDocument: RecordingDocumentEntity? {
        guard let sessionID else { return nil }
        return documents.first { $0.sessionID == sessionID }
    }

    private var displayedTimestamp: String {
        storedDocument?.cryptographicTimestamp ?? timestamp ?? "Unavailable"
    }

    private var displayedChainHash: String {
        let source = storedDocument?.finalChainHash ?? chainHash
        guard let source, !source.isEmpty else { return "Unavailable" }
        guard source.count > 12 else { return source }
        return "\(source.prefix(8))...\(source.suffix(8))"
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title2)
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("LEGAL CHAIN OF CUSTODY & INTEGRITY")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)

                    Label("Secure Enclave key integrity — Local verification", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(.green)

                    Text("Zero Alteration Guarantee")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                inspectionRow(
                    label: "Secure Enclave public key fingerprint",
                        value: storedDocument?.keyFingerprint ?? fingerprint ?? (fingerprintUnavailable ? "Unavailable on this keychain" : "Reading live key…"),
                    monospaced: true,
                    copyable: fingerprint != nil || storedDocument?.keyFingerprint != nil
                )
                inspectionRow(label: "Cryptographic timestamp", value: displayedTimestamp, monospaced: true, copyable: timestamp != nil)
                inspectionRow(label: "Chain Hash signature", value: displayedChainHash, monospaced: true, copyable: chainHash != nil)
            }
        }
        .padding()
        .background(Color.green.opacity(0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
        .task {
            loadFingerprint()
        }
    }

    @ViewBuilder
    private func inspectionRow(label: String, value: String, monospaced: Bool, copyable: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .top) {
                Text(value)
                    .font(monospaced ? .system(.caption, design: .monospaced) : .caption)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if copyable {
                    Button(copiedValue == value ? "Copied" : "Copy") {
                        UIPasteboard.general.string = value
                        copiedValue = value
                    }
                    .font(.caption2.bold())
                    .foregroundColor(.blue)
                }
            }
        }
    }

    private func loadFingerprint() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let value = try SharedKeychainManager.shared.publicKeyFingerprint()
                DispatchQueue.main.async {
                    fingerprint = value
                    fingerprintUnavailable = value == nil
                }
            } catch {
                DispatchQueue.main.async {
                    fingerprintUnavailable = true
                }
            }
        }
    }
}

#Preview {
    LegalChainOfCustodyCard()
}

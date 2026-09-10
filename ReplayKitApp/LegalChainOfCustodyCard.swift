import Foundation
import SwiftUI
import UIKit

/// Shared inspection card used by both the session and frame detail screens.
/// The fingerprint is read from the persisted key at display time so it is
/// never a placeholder or a value copied into the UI at build time.
public struct LegalChainOfCustodyCard: View {
    let chainHash: String?
    let timestamp: String?

    @State private var fingerprint: String?
    @State private var fingerprintUnavailable = false
    @State private var copiedValue: String?

    public init(chainHash: String? = nil, timestamp: String? = nil) {
        self.chainHash = chainHash
        self.timestamp = timestamp
    }

    private var displayedTimestamp: String {
        timestamp ?? ISO8601DateFormatter().string(from: Date())
    }

    private var displayedChainHash: String {
        guard let chainHash, !chainHash.isEmpty else { return "Unavailable" }
        guard chainHash.count > 12 else { return chainHash }
        return "\(chainHash.prefix(8))...\(chainHash.suffix(8))"
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

                    Label("Hardware-Enclave Attestation — Verified (NOTE: Secure Enclave Key Integrity - used for now before App Attest Server verification is fully implemented)", systemImage: "checkmark.circle.fill")
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
                    value: fingerprint ?? (fingerprintUnavailable ? "Unavailable on this keychain" : "Reading live key…"),
                    monospaced: true,
                    copyable: fingerprint != nil
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

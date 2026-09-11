import SwiftUI
import SwiftData

public struct PersistenceStatusCard: View {
    @Query private var documents: [RecordingDocumentEntity]
    let sessionID: String

    public init(sessionID: String) {
        self.sessionID = sessionID
    }

    private var document: RecordingDocumentEntity? {
        documents.first { $0.sessionID == sessionID }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Persistence", systemImage: document?.persistenceStatus == "verified" ? "checkmark.circle.fill" : "clock.fill")
                .font(.headline)
                .foregroundStyle(document?.persistenceStatus == "verified" ? .green : .orange)

            if let document {
                Text(document.persistenceStatus == "verified" ? "Saved securely" : "Needs attention")
                    .font(.subheadline.weight(.semibold))
                Text("SwiftData catalog • (document.frameCount) encrypted frame records • encrypted video at rest")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(document.validationMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Saving session evidence…")
                    .font(.subheadline.weight(.semibold))
                Text("The recording and frame ledger are being added to the local catalog.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

#Preview {
    PersistenceStatusCard(sessionID: "12345")
}

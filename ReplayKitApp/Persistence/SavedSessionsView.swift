import SwiftUI
import SwiftData

public struct SavedSessionsView: View {
    @Query(sort: \RecordingDocumentEntity.createdAt, order: .reverse)
    private var documents: [RecordingDocumentEntity]

    public init() {}

    public var body: some View {
        List(documents) { document in
            NavigationLink {
                SavedSessionDetailView(document: document)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.createdAt, style: .date)
                        .font(.headline)
                    Text("\(document.frameCount) frames • \(document.persistenceStatus == "verified" ? "Saved securely" : "Needs attention")")
                        .font(.caption)
                        .foregroundStyle(document.persistenceStatus == "verified" ? .green : .orange)
                }
            }
        }
        .navigationTitle("Saved Sessions")
        .overlay {
            if documents.isEmpty {
                ContentUnavailableView("No saved sessions", systemImage: "externaldrive", description: Text("Completed recordings will appear here."))
            }
        }
    }
}

private struct SavedSessionDetailView: View {
    let document: RecordingDocumentEntity

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if document.encryptedVideoName != nil {
                    EncryptedVideoPlayerView(sessionID: document.sessionID)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                }
                LegalChainOfCustodyCard(sessionID: document.sessionID)
                PersistenceStatusCard(sessionID: document.sessionID)
                EncryptedFrameGalleryView(sessionID: document.sessionID)
            }
            .padding(.vertical)
        }
        .navigationTitle("Session Evidence")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview ("SavedSessionsView") {
    SavedSessionsView()
}

#Preview ("SavedSessionDetailView") {
    SavedSessionDetailView(document: RecordingDocumentEntity(sessionID: "12345", userID: "1"))
}

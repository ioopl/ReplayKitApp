import SwiftUI
import SwiftData

public struct SavedSessionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecordingDocumentEntity.createdAt, order: .reverse)
    private var documents: [RecordingDocumentEntity]

    @State private var documentToRename: RecordingDocumentEntity?
    @State private var renameText = ""
    @State private var documentToDelete: RecordingDocumentEntity?
    @State private var showRenameAlert = false
    @State private var showDeleteAlert = false
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        List(documents) { document in
            NavigationLink {
                SavedSessionDetailView(document: document)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.title)
                        .font(.headline)
                    Text("\(document.frameCount) frames • \(document.persistenceStatus == "verified" ? "Saved securely" : "Needs attention")")
                        .font(.caption)
                        .foregroundStyle(document.persistenceStatus == "verified" ? .green : .orange)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    documentToDelete = document
                    showDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Button {
                    beginRename(document)
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(.blue)
            }
            .contextMenu {
                Button {
                    beginRename(document)
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    documentToDelete = document
                    showDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Saved Sessions")
        .overlay {
            if documents.isEmpty {
                ContentUnavailableView("No saved sessions", systemImage: "externaldrive", description: Text("Completed recordings will appear here."))
            }
        }
        .alert("Rename Session", isPresented: $showRenameAlert) {
            TextField("Session name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                saveRename()
            }
            .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Choose a name that will help you find this recording later.")
        }
        .alert("Delete Session?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteSelectedSession()
            }
        } message: {
            Text("This permanently removes the encrypted video, frame evidence, and saved-session record from this device.")
        }
        .alert("Unable to Update Session", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func beginRename(_ document: RecordingDocumentEntity) {
        documentToRename = document
        renameText = document.title
        showRenameAlert = true
    }

    private func saveRename() {
        guard let documentToRename else { return }
        let cleanedName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }
        documentToRename.title = cleanedName
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
        self.documentToRename = nil
    }

    private func deleteSelectedSession() {
        guard let documentToDelete else { return }
        do {
            try EncryptedFrameStore.shared.deleteSession(documentToDelete.sessionID)
            modelContext.delete(documentToDelete)
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
        self.documentToDelete = nil
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

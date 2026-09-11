import SwiftUI
import SwiftData

public struct PersistenceRecoveryView<Content: View>: View {
    @Environment(\.modelContext) private var modelContext
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content.task {
            await recoverCatalog()
        }
    }

    @MainActor
    private func recoverCatalog() async {
        for sessionID in EncryptedFrameStore.shared.availableSessionIDs() {
            let metadata = (try? EncryptedFrameStore.shared.metadata(for: sessionID)) ?? []
            guard !metadata.isEmpty else { continue }
            let exists = (try? modelContext.fetch(FetchDescriptor<RecordingDocumentEntity>(
                predicate: #Predicate { $0.sessionID == sessionID }
            )))?.isEmpty == false
            if exists { continue }

            try? RecordingPersistence.importSession(
                sessionID: sessionID,
                duration: 0,
                finalChainHash: metadata.last?.chainHash ?? "Unavailable",
                cryptographicTimestamp: metadata.last?.timestamp ?? "Unavailable",
                keyFingerprint: (try? SharedKeychainManager.shared.publicKeyFingerprint()) ?? "Unavailable",
                videoSize: 0,
                context: modelContext
            )
        }
    }
}


#Preview {
    PersistenceRecoveryView(content: {})
}

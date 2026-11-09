import SwiftUI
import SwiftData
import LocalAuthentication

/// Full-screen settings view accessible via the ⚙ toolbar button.
public struct SettingsView: View {
    @ObservedObject private var settings = CaptureSettings.shared
    @ObservedObject private var drawingManager = DrawingCanvasManager.shared
    @State private var showBrowseAndDraw = false
    @State private var isDrawingMode = true
    @State private var showDeleteConfirmation = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                // Section 1: Live Screen Drawing
                Section {
                    Toggle(isOn: $drawingManager.isDrawingActive) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "scribble.variable")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.purple)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Live Screen Drawing")
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.primary)
                                Text("Enable telestrator tools to sketch over apps")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Live Screen Drawing")
                } footer: {
                    Text("Enables the floating on-screen telestrator toolbar while broadcasting across apps.")
                }

                // Section 2: Browse and Draw in Web
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "safari.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.blue)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Browse & Draw in Web")
                                    .font(.body.weight(.medium))
                                    .foregroundColor(.primary)
                                Text("In-app browser with overlay annotation tools")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Button(action: {
                            showBrowseAndDraw = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "safari")
                                    .font(.subheadline.weight(.semibold))
                                Text("Browse and Draw in Web") // Main Label for the Button
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(Color.green)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Browse and Draw in Web")// HEADER
                } footer: {
                    Text("Open an independent in-app browser with drawing tools to navigate and annotate web pages.")
                }

                // Section 3: Hashing Pipeline
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Frame Integrity Definition", systemImage: "cpu")
                            .font(.headline)
                        Text("Choose when SHA-256 is computed in the capture pipeline. Applies to both Option B (In-App) and Option C (System-Wide) capture sessions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Hashing Pipeline")
                }

                Section {
                    ForEach(HashingPipeline.allCases, id: \.self) { pipeline in
                        Button(action: {
                            withAnimation(.spring(response: 0.3)) {
                                settings.hashingPipeline = pipeline
                            }
                        }) {
                            HStack(alignment: .top, spacing: 14) {
                                // Selection indicator
                                ZStack {
                                    Circle()
                                        .stroke(settings.hashingPipeline == pipeline ? Color.blue : Color.secondary.opacity(0.4), lineWidth: 2)
                                        .frame(width: 22, height: 22)
                                    if settings.hashingPipeline == pipeline {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 13, height: 13)
                                    }
                                }
                                .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(spacing: 6) {
                                        Text(pipelineIndex(pipeline))
                                            .font(.caption2.bold())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(pipelineColor(pipeline))
                                            .cornerRadius(4)

                                        Text(pipeline.displayName)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.primary)
                                    }

                                    Text(pipeline.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    if pipeline == .pixelBuffer {
                                        PipelineDiagram(steps: [
                                            ("camera.aperture", "CVPixelBuffer", .blue),
                                            ("arrow.right", nil, .secondary),
                                            ("key.fill", "SHA-256", .orange),
                                            ("arrow.right", nil, .secondary),
                                            ("doc.fill", "JPEG Encode", .purple),
                                            ("arrow.right", nil, .secondary),
                                            ("lock.fill", "AES-GCM", .red),
                                        ])
                                    } else {
                                        PipelineDiagram(steps: [
                                            ("camera.aperture", "CVPixelBuffer", .blue),
                                            ("arrow.right", nil, .secondary),
                                            ("doc.fill", "JPEG Encode", .purple),
                                            ("arrow.right", nil, .secondary),
                                            ("key.fill", "SHA-256", .orange),
                                            ("arrow.right", nil, .secondary),
                                            ("lock.fill", "AES-GCM", .red),
                                        ])
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(settings.hashingPipeline == pipeline
                            ? pipelineColor(pipeline).opacity(0.07)
                            : Color(.secondarySystemGroupedBackground))
                    }
                } header: {
                    Text("Select Pipeline")
                } footer: {
                    Text("The selected pipeline is shown in the Frame Integrity Ledger header and reflected in the FrameDetailView diagram.")
                }

                // Section 4: Capture Characteristics
                Section {
                    InfoRow(icon: "shield.lefthalf.filled", label: "Encryption", value: "AES-256-GCM (CryptoKit)")
                    InfoRow(icon: "key.horizontal.fill", label: "Key Storage", value: "Secure Enclave / Keychain")
                    InfoRow(icon: "link.circle.fill", label: "Chain Algorithm", value: "SHA-256(frameHash + prevChain)")
                    InfoRow(icon: "memorychip", label: "Max Ledger Rows", value: "20 most recent frames")
                } header: {
                    Text("Capture Characteristics")
                }

                // Section 5: Session Management (Logout)
                Section {
                    Button(action: handleLogout) {
                        HStack {
                            Spacer()
                            Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                } header: {
                    Text("Session")
                } footer: {
                    Text("Logging out ends your active capture session and unauthorizes screen recording.")
                }

                // Section 6: Data Management (Delete Data)
                Section {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Label("Delete Data", systemImage: "trash.fill")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Permanently deletes all stored recordings, encrypted frames, and broadcast history. Requires biometric authentication.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
            .fullScreenCover(isPresented: $showBrowseAndDraw) {
                BrowseAndDrawView(
                    manager: drawingManager,
                    isDrawingMode: $isDrawingMode,
                    isBroadcasting: false
                )
            }
            .alert("Delete All Recording Data?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Continue & Authenticate", role: .destructive) {
                    authenticateAndDeleteData()
                }
            } message: {
                Text("This action cannot be undone. It will permanently delete all previous broadcasts, screen recordings, encrypted frames, and metadata. You must authenticate to proceed.")
            }
            .alert("Deletion Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
        }
    }

    private func handleLogout() {
        try? SharedKeychainManager.shared.deleteSymmetricKey()
        DrawingCanvasManager.shared.isDrawingActive = false
        NotificationCenter.default.post(name: .appUserDidLogout, object: nil)
        dismiss()
    }

    private func authenticateAndDeleteData() {
        #if targetEnvironment(simulator)
        performDataDeletionAndLogout()
        #else
        let context = LAContext()
        var error: NSError?
        let reason = "Authenticate with Face ID or device passcode to confirm and permanently delete all recording data."

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
                DispatchQueue.main.async {
                    if success {
                        performDataDeletionAndLogout()
                    } else {
                        errorMessage = authError?.localizedDescription ?? "Authentication was not completed."
                        showErrorAlert = true
                    }
                }
            }
        } else {
            performDataDeletionAndLogout()
        }
        #endif
    }

    private func performDataDeletionAndLogout() {
        // 1. Purge encrypted frame sessions and broadcast recordings
        try? EncryptedFrameStore.shared.deleteAllData()

        // 2. Delete SwiftData documents and frames
        try? modelContext.delete(model: FrameEntity.self)
        try? modelContext.delete(model: RecordingDocumentEntity.self)
        try? modelContext.save()

        // 3. Clear App Group UserDefaults
        if let defaults = UserDefaults(suiteName: "group.com.apkia.replaykitapp.shared") {
            defaults.removeObject(forKey: "frameMetadata")
            defaults.removeObject(forKey: "broadcastActive")
            defaults.removeObject(forKey: "broadcastFinished")
            defaults.removeObject(forKey: "broadcastSessionID")
            defaults.removeObject(forKey: "broadcastFinishedSessionID")
            defaults.removeObject(forKey: "broadcastVideoSampleCount")
            defaults.removeObject(forKey: "broadcastReceivedSampleCount")
            defaults.removeObject(forKey: "broadcastVideoBufferCount")
            defaults.removeObject(forKey: "broadcastVideoFormat")
            defaults.removeObject(forKey: "broadcastWriterStatus")
            defaults.removeObject(forKey: "broadcastWriterError")
            defaults.removeObject(forKey: "broadcastWriterErrorDomain")
            defaults.removeObject(forKey: "broadcastWriterErrorCode")
            defaults.synchronize()
        }

        // 4. Delete symmetric session key
        try? SharedKeychainManager.shared.deleteSymmetricKey()

        // 5. Clear drawing canvas
        DrawingCanvasManager.shared.clear()
        DrawingCanvasManager.shared.isDrawingActive = false

        // 6. Post deletion and logout notifications
        NotificationCenter.default.post(name: .appDataDidDelete, object: nil)
        NotificationCenter.default.post(name: .appUserDidLogout, object: nil)

        // 7. Dismiss SettingsView
        dismiss()
    }

    private func pipelineIndex(_ p: HashingPipeline) -> String {
        switch p {
        case .pixelBuffer: return "1"
        case .jpegFirst:   return "2"
        }
    }

    private func pipelineColor(_ p: HashingPipeline) -> Color {
        switch p {
        case .pixelBuffer: return .blue
        case .jpegFirst:   return .orange
        }
    }
}

// MARK: - Mini pipeline diagram
private struct PipelineDiagram: View {
    let steps: [(String, String?, Color)]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(steps.indices, id: \.self) { i in
                    let (icon, label, color) = steps[i]
                    if icon == "arrow.right" {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    } else if let text = label {
                        HStack(spacing: 3) {
                            Image(systemName: icon)
                                .font(.system(size: 8))
                            Text(text)
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundColor(color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.12))
                        .cornerRadius(5)
                    }
                }
            }
        }
        .padding(.top, 6)
    }
}

// MARK: - Info row helper
private struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    SettingsView()
}

import SwiftUI
import ReplayKit

public struct SystemWideScreenBroadcastView: View {
    @StateObject private var viewModel = SystemWideScreenBroadcastViewModel()
    @ObservedObject private var settings = CaptureSettings.shared
    @State private var selectedRecord: FrameRecord? = nil
    @State private var showSettings = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
            ScrollView {
                Text("Launch the system broadcast picker to record and stream using the Broadcast Upload Extension. This option captures the entire iOS screen (Home screen, other apps, notifications). It spawns a separate system process (the Broadcast Upload Extension).")
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            ScrollView {
                Text("Note: Auth Status refers to verifying that the main app (or user session) is authenticated with our server backend or local security layer before initiating the stream. \n\nBecause the Broadcast Extension runs as a separate binary target: \n\nThe main app authenticates the user (e.g., getting a JWT token or stream key). \n\nIt saves this key/token into NSUserDefaults (with App Groups) or Keychain (Shared Access Group). \n\nThe Broadcast Extension reads the token from the shared storage to authorize the streaming session with our server/CDN.")
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            ScrollView {
                Text("Network Payload: Typically encoded and streamed to a streaming server (WebRTC/gRPC) in real time.")
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.green)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Status Block
            VStack(spacing: 12) {
                HStack {
                    Text("Auth Status:")
                        .bold()
                    Spacer()
                    Text(viewModel.isAuthenticated ? "Authenticated" : "Unauthenticated")
                        .foregroundColor(viewModel.isAuthenticated ? .green : .orange)
                        .bold()
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                HStack {
                    Text("Security Status:")
                        .bold()
                    Spacer()
                    Text(viewModel.keyStatus)
                        .foregroundColor(viewModel.isAuthenticated ? .blue : .gray)
                        .bold()
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                // Broadcast Integrity Ledger (live, populated every 10 frames from App Group).
                // Keep the ledger visible before authentication so users can see where the
                // broadcast integrity records will appear once the extension starts writing them.
                FrameIntegrityLedgerView(
                    records: viewModel.records,
                    pipelineLabel: settings.hashingPipeline == .pixelBuffer ? "Pipeline 1" : "Pipeline 2 (JPEG-First)",
                    selectedRecord: $selectedRecord
                )
            }
            .padding(.horizontal)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            Spacer()
            
            if !viewModel.isAuthenticated {
                Button(action: {
                    viewModel.authenticateAndPrepareKeys()
                }) {
                    Text("Authenticate & Setup Keys")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            } else {
                VStack(spacing: 24) {
                    Text("Tap below to launch System Broadcast Picker:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    BroadcastPickerRepresentable()
                        .frame(width: 80, height: 80)
                    
                    Button(action: {
                        viewModel.syncPipelineToAppGroup()
                        viewModel.showSummary = true
                    }) {
                        Label("Post-Broadcast Summary", systemImage: "sparkles")
                            .font(.subheadline)
                            .foregroundColor(viewModel.lastVideoURL != nil ? .purple : .gray)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(viewModel.lastVideoURL != nil ? Color.purple.opacity(0.1) : Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(viewModel.lastVideoURL != nil ? Color.purple.opacity(0.3) : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal)
                    }
                    .disabled(viewModel.lastVideoURL == nil)
                }
            }
        }
        .padding()
        .navigationTitle("System-Wide Screen Broadcast")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.body)
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showSummary || viewModel.showMockSummary },
            set: { newValue in
                if !newValue {
                    viewModel.showSummary = false
                    viewModel.showMockSummary = false
                }
            }
        )) {
            PostSessionSummaryView(
                title: "Broadcast Ended",
                duration: viewModel.lastSessionDuration,
                mode: .local(videoURL: viewModel.lastVideoURL, fileSize: viewModel.lastSessionSize),
                onDismiss: {
                    viewModel.showSummary = false
                    viewModel.showMockSummary = false
                },
                onDeleteBuffer: {
                    viewModel.deleteLocalBuffer()
                }
            )
        }
        .sheet(item: $selectedRecord) { record in
            FrameDetailView(record: record)
        }
        .onAppear {
            // Sync pipeline setting each time this view appears so SampleHandler always has the latest
            viewModel.syncPipelineToAppGroup()
        }
            .onChange(of: settings.hashingPipeline) { _ in
                viewModel.syncPipelineToAppGroup()
            }
        }
    }
}

struct BroadcastPickerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        picker.showsMicrophoneButton = true
        // Set this to our actual Broadcast Extension bundle ID
        picker.preferredExtension = "com.example.ReplayKitApp.BroadcastExtension"
        return picker
    }
    
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

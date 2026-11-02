import SwiftUI
import ReplayKit

public struct SystemWideScreenBroadcastView: View {
    @StateObject private var viewModel = SystemWideScreenBroadcastViewModel()
    @ObservedObject private var settings = CaptureSettings.shared
    @State private var selectedRecord: FrameRecord? = nil
    @State private var showSettings = false
    @State private var isDrawingMode = true
    @State private var isBrowseDrawActive = false
    @State private var showDrawingOptions = false

    public init() {}

    private var heroTitle: String {
        if !viewModel.isAuthenticated {
            return "Authentication Required"
        } else if viewModel.isBroadcasting {
            return "Screen Recording Active"
        } else {
            return "System-Wide Screen Record"
        }
    }

    private var heroSubtitle: String {
        if !viewModel.isAuthenticated {
            return "Authenticate with Face ID or device passcode to generate hardware-bound encryption keys before broadcasting."
        } else if viewModel.isBroadcasting {
            return "Your entire iOS screen is being captured, encrypted, and streamed in real time."
        } else {
            return "Capture your entire iOS screen across all apps and stream or encrypt frames in real time."
        }
    }

    public var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // MARK: - Center Hero Badge (Apple Continuity style)
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 96, height: 96)
                                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)

                            if !viewModel.isAuthenticated {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 42, weight: .regular))
                                    .foregroundColor(.black)
                            } else if viewModel.isBroadcasting {
                                Image(systemName: "record.circle.fill")
                                    .font(.system(size: 46, weight: .regular))
                                    .foregroundColor(.red)
                            } else {
                                Image(systemName: "record.circle")
                                    .font(.system(size: 46, weight: .regular))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.top, 16)

                        VStack(spacing: 6) {
                            Text(heroTitle)
                                .font(.system(size: 24, weight: .bold, design: .default))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)

                            Text(heroSubtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .padding(.horizontal, 24)
                        }
                    }

                    // MARK: - Status & Error Messages
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if let photosSaveMessage = viewModel.photosSaveMessage {
                        Text(photosSaveMessage)
                            .foregroundColor(photosSaveMessage == "Broadcast saved to Photos." ? .green : .orange)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 32)

                    // MARK: - Bottom Action Buttons (Continuity Camera Style)
                    VStack(spacing: 12) {
                        // Post-Recording Summary (Only visible when a recording exists)
                        if viewModel.hasRecording {
                            Button(action: {
                                viewModel.syncPipelineToAppGroup()
                                viewModel.showSummary = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.headline)
                                    Text("Post-Recording Summary")
                                        .font(.headline.weight(.semibold))
                                }
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        // Authenticate or Big Red Record Button (ON TOP)
                        if !viewModel.isAuthenticated {
                            Button(action: {
                                viewModel.authenticateAndPrepareKeys()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "faceid")
                                        .font(.title3.bold())
                                    Text("Authenticate")
                                        .font(.headline.weight(.semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.blue)
                                .cornerRadius(14)
                                .shadow(color: Color.blue.opacity(0.25), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 4)
                        } else {
                            #if targetEnvironment(simulator)
                            Button(action: {
                                viewModel.simulateBroadcastEnded()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "record.circle.fill")
                                        .font(.title3.bold())
                                    Text("Start Recording (Simulator)")
                                        .font(.headline.weight(.semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(red: 1.0, green: 0.27, blue: 0.23))
                                .cornerRadius(14)
                                .shadow(color: Color.red.opacity(0.25), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 4)
                            #else
                            ZStack {
                                HStack(spacing: 10) {
                                    Image(systemName: viewModel.isBroadcasting ? "stop.circle.fill" : "record.circle.fill")
                                        .font(.title3.bold())
                                    Text(viewModel.isBroadcasting ? "Stop Screen Recording" : "Start Screen Recording")
                                        .font(.headline.weight(.semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(red: 1.0, green: 0.27, blue: 0.23))
                                .cornerRadius(14)
                                .shadow(color: Color.red.opacity(0.25), radius: 8, x: 0, y: 4)

                                BroadcastPickerRepresentable()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .opacity(0.015)
                            }
                            .frame(height: 56)
                            .padding(.horizontal, 4)
                            #endif

                            // Drawing Options Button (BELOW the Record button)
                            Button(action: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    showDrawingOptions.toggle()
                                }
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "paintpalette.fill")
                                        .font(.headline)
                                        .foregroundColor(.purple)
                                    Text(showDrawingOptions ? "Hide Drawing Options" : "Show Drawing Options")
                                        .font(.headline.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: showDrawingOptions ? "chevron.up" : "chevron.down")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(showDrawingOptions ? Color.purple.opacity(0.3) : Color.primary.opacity(0.12), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 4)
                            .accessibilityLabel(showDrawingOptions ? "Hide Drawing Options" : "Show Drawing Options")
                            .accessibilityHint("Toggles display of live screen drawing and web canvas options below.")
                            .accessibilityAddTraits(.isButton)

                            // Live Screen Drawing Options (Expands smoothly BELOW the button)
                            if showDrawingOptions {
                                LiveScreenDrawingSectionView(
                                    isDrawingActive: $viewModel.isDrawingActive,
                                    onBrowseAndDraw: {
                                        isBrowseDrawActive = true
                                        viewModel.isDrawingActive = true
                                    },
                                    isCardStyle: true
                                )
                                .padding(.horizontal, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }

            // MARK: - Live Screen Drawing Overlay
            if viewModel.isDrawingActive {
                Group {
                    if isBrowseDrawActive {
                        BrowseAndDrawView(
                            manager: (viewModel.drawingService as? DrawingCanvasManager) ?? DrawingCanvasManager.shared,
                            isDrawingMode: $isDrawingMode,
                            isBroadcasting: viewModel.isBroadcasting
                        )
                    } else {
                        DrawingCanvasContainerView(
                            manager: (viewModel.drawingService as? DrawingCanvasManager) ?? DrawingCanvasManager.shared,
                            isDrawingMode: $isDrawingMode,
                            isBroadcasting: viewModel.isBroadcasting
                        )
                    }
                }
                .transition(.opacity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Screen Record")
                    .font(.system(size: 33, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Scribble toolbar icon: Only visible when Authenticated
            if viewModel.isAuthenticated {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        withAnimation {
                            viewModel.isDrawingActive.toggle()
                            if !viewModel.isDrawingActive {
                                isBrowseDrawActive = false
                            }
                        }
                    }) {
                        Image(systemName: viewModel.isDrawingActive ? "scribble.variable" : "scribble")
                            .font(.body)
                            .foregroundColor(viewModel.isDrawingActive ? .purple : .primary)
                    }
                    .accessibilityLabel(viewModel.isDrawingActive ? "Hide Drawing Canvas" : "Show Drawing Canvas")
                }
            }

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
                },
                chainHash: viewModel.records.last?.chainHash,
                cryptographicTimestamp: viewModel.records.last?.timestamp,
                sessionID: viewModel.lastSessionID,
                encryptedVideoSessionID: viewModel.lastSessionID.flatMap { EncryptedFrameStore.shared.hasEncryptedVideo(sessionID: $0) ? $0 : nil },
                drawingSnapshot: viewModel.lastDrawingSnapshot
            )
        }
        .sheet(item: $selectedRecord) { record in
            FrameDetailView(record: record)
        }
        .onAppear {
            viewModel.syncPipelineToAppGroup()
        }
        .onChange(of: settings.hashingPipeline) { _ in
            viewModel.syncPipelineToAppGroup()
        }
        .onChange(of: viewModel.isAuthenticated) { authenticated in
            if !authenticated {
                showDrawingOptions = false
            }
        }
    }
}

// MARK: - Native ReplayKit Broadcast Picker Representable
struct BroadcastPickerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = CustomBroadcastPickerView(frame: .zero)
        picker.showsMicrophoneButton = true
        picker.preferredExtension = "com.apkia.replaykitapp.BroadcastExtension"
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

final class CustomBroadcastPickerView: RPSystemBroadcastPickerView {
    override func layoutSubviews() {
        super.layoutSubviews()
        for subview in subviews {
            if let button = subview as? UIButton {
                button.frame = bounds
            }
        }
    }
}

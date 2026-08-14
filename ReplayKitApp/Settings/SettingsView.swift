import SwiftUI

/// Full-screen settings view accessible via the ⚙ toolbar button.
public struct SettingsView: View {
    @ObservedObject private var settings = CaptureSettings.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
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

                Section {
                    InfoRow(icon: "shield.lefthalf.filled", label: "Encryption", value: "AES-256-GCM (CryptoKit)")
                    InfoRow(icon: "key.horizontal.fill", label: "Key Storage", value: "Secure Enclave / Keychain")
                    InfoRow(icon: "link.circle.fill", label: "Chain Algorithm", value: "SHA-256(frameHash + prevChain)")
                    InfoRow(icon: "memorychip", label: "Max Ledger Rows", value: "20 most recent frames")
                } header: {
                    Text("Capture Characteristics")
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
        }
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

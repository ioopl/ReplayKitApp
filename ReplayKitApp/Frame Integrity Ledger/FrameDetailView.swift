import SwiftUI

public struct FrameDetailView: View {
    let record: FrameRecord
    @ObservedObject private var settings = CaptureSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isCopied = false
    @State private var showHexPreview = false
    
    public init(record: FrameRecord) {
        self.record = record
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopied = false
        }
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 1. Frame Preview Thumbnail Card
                    VStack(spacing: 12) {
                        if let img = record.thumbnail {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 160)
                                .cornerRadius(12)
                                .shadow(radius: 4)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(16)
                        } else {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemBackground))
                                .frame(height: 160)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                )
                        }
                    }
                    .padding(.horizontal)
                    
                    // 2. Visual Relationship Diagram
                    VStack(spacing: 8) {
                        Text("CRYPTOGRAPHIC DATA FLOW")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 4) {
                            DiagramNode(label: "Frame Pixel Buffer", icon: "camera.aperture", color: .blue)
                            DiagramArrow()
                            if settings.hashingPipeline == .pixelBuffer {
                                DiagramNode(label: "SHA-256 (Pixel Bytes)", icon: "key.fill", color: .orange)
                                DiagramArrow()
                                DiagramNode(label: "JPEG Data (\(record.sizeKB))", icon: "doc.plaintext.fill", color: .purple)
                            } else {
                                DiagramNode(label: "JPEG Data (\(record.sizeKB))", icon: "doc.plaintext.fill", color: .purple)
                                DiagramArrow()
                                DiagramNode(label: "SHA-256 (JPEG Bytes)", icon: "key.fill", color: .orange)
                            }
                            DiagramArrow()
                            DiagramNode(label: "Hash-Chain Sequence", icon: "link", color: .green)
                            DiagramArrow()
                            DiagramNode(label: "AES-256-GCM Payload", icon: "lock.fill", color: .red)
                        }
                        .padding()
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    
                    // 3. Metadata Section
                    VStack(alignment: .leading, spacing: 16) {
                        DetailGroupHeader(title: "METADATA")
                        
                        DetailRow(label: "Timestamp", value: record.timestamp)
                        DetailRow(label: "Resolution", value: record.resolution)
                        DetailRow(label: "Format", value: "JPEG")
                        DetailRow(label: "JPEG Size", value: record.sizeKB)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // 4. Frame Hash Section
                    VStack(alignment: .leading, spacing: 16) {
                        DetailGroupHeader(title: "FRAME HASH")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(settings.hashingPipeline == .pixelBuffer
                                 ? "Pipeline 1 — SHA-256 (Pixel Buffer)"
                                 : "Pipeline 2 — SHA-256 (JPEG-First)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(record.sha256)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.primary)
                                .minimumScaleFactor(0.8)
                                .textSelection(.enabled)
                        }
                        
                        Button(action: {
                            copyToClipboard(record.sha256)
                        }) {
                            Label(isCopied ? "Copied!" : "Copy Hash", systemImage: isCopied ? "checkmark" : "doc.on.doc.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // 5. Hash Chain Section
                    VStack(alignment: .leading, spacing: 16) {
                        DetailGroupHeader(title: "HASH CHAIN")
                        
                        DetailRow(label: "Previous Frame", value: "#\(record.index - 1)")
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Previous Chain Hash")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(record.previousHash)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Chain Hash")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(record.chainHash)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        HStack {
                            Text("Chain Status")
                                .font(.subheadline)
                            Spacer()
                            Label(record.isChainValid ? "VALID" : "INVALID", systemImage: record.isChainValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.caption.bold())
                                .foregroundColor(record.isChainValid ? .green : .red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(record.isChainValid ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // 6. Encryption Section
                    VStack(alignment: .leading, spacing: 16) {
                        DetailGroupHeader(title: "ENCRYPTION")
                        
                        DetailRow(label: "Algorithm", value: "AES-256-GCM")
                        
                        HStack {
                            Text("Status")
                                .font(.subheadline)
                            Spacer()
                            Label("ENCRYPTED", systemImage: "lock.fill")
                                .font(.caption.bold())
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.15))
                                .cornerRadius(8)
                        }
                        
                        DetailRow(label: "Encrypted Size", value: record.sizeKB)
                        DetailRow(label: "Authentication Tag", value: "Present")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // 7. Session Section
                    VStack(alignment: .leading, spacing: 16) {
                        DetailGroupHeader(title: "SESSION")
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Session UUID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(record.sessionID)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        
                        DetailRow(label: "Sequence", value: "\(record.index) / Capture Active")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // 8. Raw Bytes Developer View
                    VStack(alignment: .leading, spacing: 12) {
                        Button(action: {
                            withAnimation {
                                showHexPreview.toggle()
                            }
                        }) {
                            HStack {
                                DetailGroupHeader(title: "RAW BYTES DEVELOPER VIEW")
                                Spacer()
                                Image(systemName: showHexPreview ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if showHexPreview {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("JPEG Binary Preview (First 32 bytes)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(record.hexDump)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.red)
                                    .padding(8)
                                    .background(Color.black.opacity(0.05))
                                    .cornerRadius(8)
                                
                                Text("Total bytes: \(record.rawSize)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("FRAME #\(record.index)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

struct DetailGroupHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.caption2.bold())
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }
}

struct DiagramNode: View {
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
            Text(label)
                .font(.caption2.bold())
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct DiagramArrow: View {
    var body: some View {
        Image(systemName: "arrow.down")
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.vertical, 2)
    }
}

#Preview {
    let record = FrameRecord(
        id: UUID(),
        index: 1,
        timestamp: "timeString",
        sizeKB: String(format: "%.1f KB", Double(100000) / 1024.0),
        rawSize: 2,
        sha256: "frameHash",
        previousHash: "prevHash",
        chainHash: "currentChainHash",
        isChainValid: true,
        isEncrypted: true,
        thumbnail: UIImage(systemName: "photo"),
        hexDump: "hexBytesString",
        sessionID: "sessionID",
        resolution: "1024x768"
    )
    FrameDetailView(record: record)
}

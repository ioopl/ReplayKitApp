import SwiftUI
import AVKit

public enum SessionMode {
    case local(videoURL: URL?, fileSize: Int64)
    case liveStream(streamURL: String, resolution: String, fps: Int)
}

public struct PostSessionSummaryView: View {
    let title: String
    let duration: TimeInterval
    let mode: SessionMode
    let onDismiss: () -> Void
    let onDeleteBuffer: (() -> Void)?
    
    @State private var isCopied = false
    @State private var showDeleteAlert = false
    @State private var isProcessing = false
    
    public init(
        title: String,
        duration: TimeInterval,
        mode: SessionMode,
        onDismiss: @escaping () -> Void,
        onDeleteBuffer: (() -> Void)? = nil
    ) {
        self.title = title
        self.duration = duration
        self.mode = mode
        self.onDismiss = onDismiss
        self.onDeleteBuffer = onDeleteBuffer
    }
    
    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var formattedFileSize: String {
        switch mode {
        case .local(_, let size):
            if size > 1024 * 1024 {
                return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
            } else {
                return String(format: "%.1f KB", Double(size) / 1024.0)
            }
        case .liveStream:
            return "N/A"
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                // Background subtle gradient
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 1. Status Summary Header
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.green.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.green)
                            }
                            .padding(.top, 16)
                            
                            Text(title)
                                .font(.title.bold())
                            
                            Text("Session completed and secured successfully.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // 2. Main Stats Summary Card
                        VStack(spacing: 16) {
                            HStack {
                                StatCell(title: "Duration", value: formattedDuration, icon: "clock.fill", color: .blue)
                                Divider()
                                    .frame(height: 40)
                                switch mode {
                                case .local:
                                    StatCell(title: "File Size", value: formattedFileSize, icon: "doc.fill", color: .orange)
                                case .liveStream(let _, let resolution, _):
                                    StatCell(title: "Resolution", value: resolution, icon: "video.fill", color: .purple)
                                }
                                Divider()
                                    .frame(height: 40)
                                switch mode {
                                case .local:
                                    StatCell(title: "Quality", value: "1080p @ 60", icon: "sparkles", color: .purple)
                                case .liveStream(let _, _, let fps):
                                    StatCell(title: "Frame Rate", value: "\(fps) FPS", icon: "waveform.path", color: .orange)
                                }
                            }
                            .padding()
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(16)
                        }
                        .padding(.horizontal)
                        
                        // 3. Processing / Video Preview Player Thumbnail
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Session Artifacts")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            VStack {
                                switch mode {
                                case .local(let videoURL, _):
                                    if let url = videoURL {
                                        VideoPlayer(player: AVPlayer(url: url))
                                            .frame(height: 200)
                                            .cornerRadius(16)
                                            .shadow(radius: 4)
                                    } else {
                                        // Mock video preview or animated loader if processing
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.black.opacity(0.85))
                                                .frame(height: 200)
                                            
                                            if isProcessing {
                                                VStack(spacing: 12) {
                                                    ProgressView()
                                                        .tint(.white)
                                                    Text("Finalizing video file...")
                                                        .font(.caption)
                                                        .foregroundColor(.white)
                                                }
                                            } else {
                                                VStack(spacing: 12) {
                                                    Image(systemName: "video.fill")
                                                        .font(.largeTitle)
                                                        .foregroundColor(.gray)
                                                    Text("Video Saved Locally (Sandbox Buffer)")
                                                        .font(.caption)
                                                        .foregroundColor(.white)
                                                }
                                            }
                                        }
                                    }
                                    
                                case .liveStream(let streamURL, _, _):
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(height: 180)
                                        
                                        VStack(spacing: 12) {
                                            Image(systemName: "antenna.radiowaves.left.and.right")
                                                .font(.system(size: 44))
                                                .foregroundColor(.white)
                                            Text("Live Stream Complete")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            Text(streamURL)
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.8))
                                                .lineLimit(1)
                                                .padding(.horizontal)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 4. Secure Encryption Status Banner
                        VStack(spacing: 12) {
                            HStack(spacing: 16) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Encrypted via CryptoKit AES-GCM with hardware-bound keys generated in the Secure Enclave.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(nil)
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal)
                        
                        // 5. Actions Card
                        VStack(spacing: 16) {
                            Text("Actions")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                switch mode {
                                case .local(let videoURL, _):
                                    if let url = videoURL {
                                        ShareLink(item: url) {
                                            Label("Share / Save Video File", systemImage: "square.and.arrow.up")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(Color.blue)
                                                .cornerRadius(12)
                                        }
                                    } else {
                                        // Mock Share
                                        Button(action: {
                                            // Handle manual trigger or simulation
                                        }) {
                                            Label("Share Video File (Simulated)", systemImage: "square.and.arrow.up")
                                                .font(.headline)
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding()
                                                .background(Color.blue)
                                                .cornerRadius(12)
                                        }
                                    }
                                    
                                case .liveStream(let streamURL, _, _):
                                    Button(action: {
                                        UIPasteboard.general.string = streamURL
                                        isCopied = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            isCopied = false
                                        }
                                    }) {
                                        Label(isCopied ? "Copied!" : "Copy Stream Recording Link", systemImage: isCopied ? "checkmark" : "doc.on.doc.fill")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(isCopied ? Color.green : Color.blue)
                                            .cornerRadius(12)
                                    }
                                }
                                
                                if let deleteAction = onDeleteBuffer {
                                    Button(action: {
                                        showDeleteAlert = true
                                    }) {
                                        Label("Delete Local Buffer", systemImage: "trash.fill")
                                            .font(.headline)
                                            .foregroundColor(.red)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.red.opacity(0.1))
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .bold()
                }
            }
            .alert("Delete Buffer?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    onDeleteBuffer?()
                    onDismiss()
                }
            } message: {
                Text("This will permanently remove the encrypted video/raw frame buffer from the App Group container and free up device storage.")
            }
        }
    }
}

struct StatCell: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .bold()
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

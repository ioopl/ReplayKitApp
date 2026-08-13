import SwiftUI

public struct InAppCaptureView: View {
    @StateObject private var viewModel = InAppCaptureViewModel()
    @State private var selectedRecord: FrameRecord? = nil
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 24) {
            Text("In-App Raw Frame Capture")
                .font(.title2)
                .bold()
                .padding(.top)
            
            ScrollView {
                VStack(spacing: 16) {
                    Text("In many production scenarios, we don't want a .MP4 file. Instead, we need the raw video feed in real time. In-App Raw Frame Capture is designed for these scenarios: \n\nA) Custom Live Streaming: Sending the screen frames directly over a WebRTC or gRPC pipeline.\n\nB) Remote Assistance & Screen Sharing: Real-time collaborative apps where an operator needs to see our app screen instantly.\n\nC) Real-time Video Processing: Applying real-time filters or computer vision analytics.")
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Text("Note: This feature captures raw screen buffers (inside the App's UI) and encrypts them in real time using CryptoKit AES-GCM (256-bit symmetric key).")
                        .font(.footnote)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
            
            // Authentication & Security Status Dashboard (Similar to Option C)
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
                
                if viewModel.isAuthenticated {
                    // Frame stats dashboard
                    VStack(spacing: 12) {
                        HStack {
                            Text("Capture State:")
                                .bold()
                            Spacer()
                            Text(viewModel.isCapturing ? "Active" : "Inactive")
                                .foregroundColor(viewModel.isCapturing ? .green : .gray)
                                .bold()
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        
                        HStack {
                            Text("Frames Processed:")
                                .bold()
                            Spacer()
                            Text("\(viewModel.frameCount)")
                                .font(.title3)
                                .foregroundColor(.blue)
                                .bold()
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        
                        HStack {
                            Text("Last Encrypted Payload:")
                                .bold()
                            Spacer()
                            Text("\(Double(viewModel.lastEncryptedSize) / 1024.0, specifier: "%.2f") KB")
                                .foregroundColor(.purple)
                                .bold()
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    
                    // Live Capture Frame Ledger
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Live Capture — Frame Integrity Ledger")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        HStack {
                            Text("#").frame(width: 30, alignment: .leading)
                            Text("Preview").frame(width: 50, alignment: .leading)
                            Text("Timestamp").frame(width: 80, alignment: .leading)
                            Text("Size").frame(width: 55, alignment: .leading)
                            Text("SHA-256").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Chain").frame(width: 50, alignment: .leading)
                            Text("AES").frame(width: 25, alignment: .center)
                        }
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                        
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(viewModel.records) { record in
                                    Button(action: {
                                        selectedRecord = record
                                    }) {
                                        HStack {
                                            Text("\(record.index)")
                                                .frame(width: 30, alignment: .leading)
                                                .foregroundColor(.secondary)
                                            
                                            Group {
                                                if let thumb = record.thumbnail {
                                                    Image(uiImage: thumb)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                } else {
                                                    Color.gray
                                                }
                                            }
                                            .frame(width: 32, height: 32)
                                            .cornerRadius(4)
                                            .clipped()
                                            .frame(width: 50, alignment: .leading)
                                            
                                            Text(record.timestamp)
                                                .frame(width: 80, alignment: .leading)
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundColor(.primary)
                                            
                                            Text(record.sizeKB)
                                                .frame(width: 55, alignment: .leading)
                                                .foregroundColor(.primary)
                                            
                                            Text(record.sha256.prefix(4) + "…" + record.sha256.suffix(4))
                                                .font(.system(.caption2, design: .monospaced))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .foregroundColor(.secondary)
                                            
                                            Text("VALID")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.green)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.15))
                                                .cornerRadius(4)
                                                .frame(width: 50, alignment: .leading)
                                            
                                            Image(systemName: "lock.fill")
                                                .font(.caption2)
                                                .foregroundColor(.red)
                                                .frame(width: 25, alignment: .center)
                                        }
                                        .font(.caption)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 6)
                                        .background(Color.secondary.opacity(0.05))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .frame(height: 150)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            Spacer()
            
            // Action Button
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
                Button(action: {
                    if viewModel.isCapturing {
                        viewModel.stopCapture()
                    } else {
                        viewModel.startCapture()
                    }
                }) {
                    Text(viewModel.isCapturing ? "Stop Capture" : "Start Capture")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(viewModel.isCapturing ? Color.red : Color.green)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }
        }
        .padding()
        .sheet(isPresented: $viewModel.showSummary) {
            PostSessionSummaryView(
                title: "Capture Completed",
                duration: viewModel.lastSessionDuration,
                mode: .local(videoURL: viewModel.lastVideoURL, fileSize: viewModel.lastSessionSize),
                onDismiss: {
                    viewModel.showSummary = false
                },
                onDeleteBuffer: {
                    viewModel.deleteLocalBuffer()
                }
            )
        }
        .sheet(item: $selectedRecord) { record in
            FrameDetailView(record: record)
        }
    }
}

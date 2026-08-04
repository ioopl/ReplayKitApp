import SwiftUI
import AVKit

public struct InAppClipsView: View {
    @StateObject private var viewModel = InAppClipsViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 24) {
            Text("In-App Clip Buffering")
                .font(.title2)
                .bold()
                .padding(.top)
            
            Text("Option D: Record a rolling buffer of our In-App Screen and export the last 15 seconds as a video file.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            // Status Info
            VStack(spacing: 12) {
                HStack {
                    Text("Buffering State:")
                        .bold()
                    Spacer()
                    Text(viewModel.isClipBuffering ? "Active" : "Inactive")
                        .foregroundColor(viewModel.isClipBuffering ? .green : .gray)
                        .bold()
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            if let exportedURL = viewModel.lastExportedClipURL {
                VStack(spacing: 8) {
                    Text("Exported Clip:")
                        .font(.headline)
                    
                    VideoPlayer(player: AVPlayer(url: exportedURL))
                        .frame(height: 200)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                if !viewModel.isClipBuffering {
                    Button(action: {
                        viewModel.startClipBuffering()
                    }) {
                        Text("Start Clip Buffering")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                } else {
                    HStack(spacing: 16) {
                        Button(action: {
                            viewModel.exportClip()
                        }) {
                            HStack {
                                if viewModel.isExporting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 8)
                                }
                                Text("Export 15s Clip")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            viewModel.stopClipBuffering()
                        }) {
                            Text("Stop Buffering")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
    }
}

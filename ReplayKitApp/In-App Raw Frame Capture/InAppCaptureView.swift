import SwiftUI

public struct InAppCaptureView: View {
    @StateObject private var viewModel = InAppCaptureViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 24) {
            Text("In-App Raw Frame Capture")
                .font(.title2)
                .bold()
                .padding(.top)
            
            Text("Capture raw screen buffers and encrypt them in real time using CryptoKit AES-GCM. In many production scenarios, we don't want a file. Instead, we need the raw video feed in real time. \nIn-App Raw Frame Capture is designed for these scenarios: \nA) Custom Low-Latency Live Streaming: Sending the screen frames directly over a WebRTC or gRPC pipeline to a streaming platform (like Twitch, YouTube Live, or an enterprise webinar tool). \nB) Remote Assistance & Screen Sharing: Real-time collaborative apps (like Zoom, MS Teams, TeamViewer) where an operator needs to see your app screen instantly. \nC) Real-time Video Processing: Applying real-time filters, computer vision analytics, or watermarking on the screen feed before transmitting it.")
                .font(.footnote)
                .multilineTextAlignment(.leading)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            // Frame stats dashboard
            VStack(spacing: 16) {
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
            .padding(.horizontal)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            Spacer()
            
            // Action Button
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
        .padding()
    }
}

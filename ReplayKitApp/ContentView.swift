import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Broadcast Client")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("High-security, low-latency ReplayKit broadcasting demo.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Welcome Card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Production Architecture", systemImage: "lock.shield.fill")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("Demonstrates Secure Enclave key isolation, CryptoKit AES-GCM real-time frame encryption, and strict 50MB extension memory optimization.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // 4 Action Cards
                    VStack(spacing: 16) {
                        NavigationLink(destination: InAppRecordingView()) {
                            MenuCard(
                                title: "A) In-App Screen Recording",
                                subtitle: "Record screen and present default video editor preview. Produce a local, fully finished MP4 video file.",
                                icon: "record.circle",
                                color: .red
                            )
                        }
                        
                        NavigationLink(destination: InAppCaptureView()) {
                            MenuCard(
                                title: "B) In-App Raw Frame Capture",
                                subtitle: "Capture raw screen buffers and encrypt them in real time using CryptoKit AES-GCM. Custom Low-Latency Live Streaming. Remote Assistance & Screen Sharing. Real-time Video Processing.",
                                icon: "camera.aperture",
                                color: .green
                            )
                        }
                        
                        NavigationLink(destination: SystemWideScreenBroadcastView()) {
                            MenuCard(
                                title: "C) System Wide - Screen Broadcast",
                                subtitle: "Launch System Broadcast picker for Broadcast Upload Extension. The Broadcast Upload Extension is designed for live streaming and cross-app background capture.",
                                icon: "antenna.radiowaves.left.and.right",
                                color: .blue
                            )
                        }
                        
                        NavigationLink(destination: InAppClipsView()) {
                            MenuCard(
                                title: "D) Rolling Clips Recording",
                                subtitle: "Start a rolling clip buffer to export the last 15 seconds",
                                icon: "clock.arrow.2.circlepath",
                                color: .purple
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MenuCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.footnote)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    ContentView()
}

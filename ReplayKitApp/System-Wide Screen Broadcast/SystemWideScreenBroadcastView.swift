import SwiftUI
import ReplayKit

public struct SystemWideScreenBroadcastView: View {
    @StateObject private var viewModel = SystemWideScreenBroadcastViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 24) {
            Text("System-Wide Screen Broadcasting")
                .font(.title2)
                .bold()
                .padding(.top)
            
            Text("Launch the system broadcast picker to record and stream using the Broadcast Upload Extension.")
                .font(.body)
                .multilineTextAlignment(.leading)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            ScrollView {
                Text("Note: Auth Status refers to verifying that the main app (or user session) is authenticated with your server backend or local security layer before initiating the stream. \nBecause the Broadcast Extension runs as a separate binary target: \nThe main app authenticates the user (e.g., getting a JWT token or stream key). \nIt saves this key/token into NSUserDefaults (with App Groups) or Keychain (Shared Access Group). \nThe Broadcast Extension reads the token from the shared storage to authorize the streaming session with your server/CDN.")
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
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
                VStack(spacing: 16) {
                    Text("Tap below to launch System Broadcast Picker:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    BroadcastPickerRepresentable()
                        .frame(width: 80, height: 80)
                }
            }
        }
        .padding()
    }
}

struct BroadcastPickerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        picker.showsMicrophoneButton = true
        // Set this to your actual Broadcast Extension bundle ID
        picker.preferredExtension = "com.example.ReplayKitApp.BroadcastExtension"
        return picker
    }
    
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

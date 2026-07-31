import SwiftUI
import ReplayKit

public struct InAppRecordingView: View {
    @StateObject private var viewModel = InAppRecordingViewModel()
    @State private var showPreview = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 24) {
            Text("In-App Screen Recording")
                .font(.title2)
                .bold()
                .padding(.top)
            
            Text("In-App Screen Recording is designed to produce a local, fully finished MP4 video file. Direct screen capture using RPScreenRecorder. \nSeamless integration with iOS native video editor controller (RPPreviewViewController) to let users view, trim, and share recordings instantly. \nStopping the recording will display the system preview editor.")
                .font(.body)
                .multilineTextAlignment(.leading)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            // Status Icon
            ZStack {
                Circle()
                    .fill(viewModel.isRecording ? Color.red.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(viewModel.isRecording ? .red : .blue)
                    .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                    .animation(viewModel.isRecording ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default, value: viewModel.isRecording)
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            Spacer()
            
            // Action Button
            Button(action: {
                if viewModel.isRecording {
                    viewModel.stopRecording()
                } else {
                    viewModel.startRecording()
                }
            }) {
                Text(viewModel.isRecording ? "Stop Recording" : "Start Recording")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(viewModel.isRecording ? Color.red : Color.blue)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
        }
        .padding()
        .onChange(of: viewModel.previewController) { _, newController in
            if newController != nil {
                showPreview = true
            }
        }
        .sheet(isPresented: $showPreview, onDismiss: {
            viewModel.previewController = nil
        }) {
            if let preview = viewModel.previewController {
                RPPreviewRepresentable(previewViewController: preview)
            }
        }
    }
}

struct RPPreviewRepresentable: UIViewControllerRepresentable {
    let previewViewController: RPPreviewViewController
    
    func makeUIViewController(context: Context) -> RPPreviewViewController {
        previewViewController.previewControllerDelegate = context.coordinator
        return previewViewController
    }
    
    func updateUIViewController(_ uiViewController: RPPreviewViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, RPPreviewViewControllerDelegate {
        var parent: RPPreviewRepresentable
        
        init(_ parent: RPPreviewRepresentable) {
            self.parent = parent
        }
        
        func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
            previewController.dismiss(animated: true)
        }
    }
}

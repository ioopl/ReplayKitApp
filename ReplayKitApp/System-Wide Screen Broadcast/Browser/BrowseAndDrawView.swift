import SwiftUI
import WebKit

// MARK: - In-App Browse & Draw

/// A browser-backed drawing surface. This keeps the content and PencilKit in
/// the same app, which is the supported way to provide interactive drawing
/// controls while recording.
public struct BrowseAndDrawView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var manager: DrawingCanvasManager
    @ObservedObject var blurManager: BlurLensManager
    @Binding var isDrawingMode: Bool
    var isBroadcasting: Bool

    @State private var addressText = "https://www.apple.com"
    @State private var pageURL = URL(string: "https://www.apple.com")!

    public init(
        manager: DrawingCanvasManager = .shared,
        blurManager: BlurLensManager = .shared,
        isDrawingMode: Binding<Bool>,
        isBroadcasting: Bool
    ) {
        self.manager = manager
        self.blurManager = blurManager
        self._isDrawingMode = isDrawingMode
        self.isBroadcasting = isBroadcasting
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Web content ──────────────────────────────────────────
                InAppWebView(url: pageURL)
                    .ignoresSafeArea()

                // ── Canvas background mode tint ──────────────────────────
                switch manager.backgroundMode {
                case .transparentOverlay: Color.clear
                case .whiteboard:        Color.white.opacity(0.96)
                case .blackboard:        Color(red: 0.12, green: 0.14, blue: 0.13).opacity(0.96)
                }

                // ── PencilKit annotation layer ───────────────────────────
                PencilCanvasRepresentable(
                    manager: manager,
                    isInteractionEnabled: isDrawingMode && !blurManager.isBlurModeActive
                )
                .ignoresSafeArea()

                // ── Blur Lens Overlay ────────────────────────────────────
                BlurLensOverlayView(
                    blurManager: blurManager,
                    containerSize: geo.size
                )
                .ignoresSafeArea()
                .allowsHitTesting(blurManager.isBlurModeActive || !blurManager.lenses.isEmpty)

                // ── Chrome: address bar + toolbar ────────────────────────
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        TextField("Enter a website", text: $addressText)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .submitLabel(.go)
                            .onSubmit { navigate() }

                        Button("Go", action: navigate)
                            .buttonStyle(.borderedProminent)

                        Button("Done") { dismiss() }
                            .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .background(.ultraThinMaterial)

                    if isBroadcasting {
                        Text("REC ● Browse & Draw is included in the recording")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(.black.opacity(0.75)))
                    }

                    Spacer()

                    DrawingToolbarView(
                        manager: manager,
                        blurManager: blurManager,
                        isDrawingMode: $isDrawingMode
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .onAppear {
            manager.updateHostAppBackgroundState(false)
        }
        .onChange(of: scenePhase) { _, phase in
            manager.updateHostAppBackgroundState(phase != .active)
        }
    }

    private func navigate() {
        var value = addressText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.contains("://") { value = "https://" + value }
        guard let url = URL(string: value) else { return }
        pageURL = url
        addressText = url.absoluteString
    }
}

private struct InAppWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url?.absoluteString != url.absoluteString else { return }
        webView.load(URLRequest(url: url))
    }
}

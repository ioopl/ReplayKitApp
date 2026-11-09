import SwiftUI

/**
 DrawingCanvasContainerView`: Fullscreen container supporting Transparent Overlay, Whiteboard, and Blackboard with live broadcast status.
 */
// MARK: - Drawing Canvas Container View

public struct DrawingCanvasContainerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var manager: DrawingCanvasManager
    @ObservedObject var blurManager: BlurLensManager
    @Binding var isDrawingMode: Bool
    var isBroadcasting: Bool

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
                // ── Background ───────────────────────────────────────────
                switch manager.backgroundMode {
                case .transparentOverlay:
                    Color.clear
                case .whiteboard:
                    Color.white.ignoresSafeArea()
                case .blackboard:
                    Color(red: 0.12, green: 0.14, blue: 0.13).ignoresSafeArea()
                }

                // ── PencilKit Canvas ─────────────────────────────────────
                PencilCanvasRepresentable(
                    manager: manager,
                    isInteractionEnabled: isDrawingMode && !blurManager.isBlurModeActive
                )
                .ignoresSafeArea()

                // ── Blur Lens Overlay (sits above the canvas) ────────────
                BlurLensOverlayView(
                    blurManager: blurManager,
                    containerSize: geo.size
                )
                .ignoresSafeArea()
                // Intercept touches only when placement mode is active or a
                // lens is present — otherwise let PencilKit handle all input.
                .allowsHitTesting(blurManager.isBlurModeActive || !blurManager.lenses.isEmpty)

                // ── HUD + Toolbar ────────────────────────────────────────
                VStack {
                    if isBroadcasting {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                            Text("REC ● Screen Drawing Captured Live")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.75))
                                .overlay(Capsule().stroke(Color.red.opacity(0.6), lineWidth: 1))
                        )
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
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
}

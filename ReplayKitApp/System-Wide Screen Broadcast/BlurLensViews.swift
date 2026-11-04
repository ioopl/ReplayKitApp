import SwiftUI

// Local helper to scale a CGSize by a uniform factor
fileprivate extension CGSize {
    func scaled(by factor: CGFloat) -> CGSize {
        CGSize(width: self.width * factor, height: self.height * factor)
    }
}

// MARK: - AnyShape helper

private struct AnyShape: Shape {
    private let _path: (CGRect) -> Path
    init<S: Shape>(_ shape: S) { _path = { shape.path(in: $0) } }
    func path(in rect: CGRect) -> Path { _path(rect) }
}

// MARK: - System Blur (UIVisualEffectView wrapper)

/// Wraps UIVisualEffectView so every pixel underneath is truly blurred
/// (video frames, web content, camera feed, anything rendered by the OS).
private struct SystemBlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - Resize Handle

/// A small grippy chevron triangle at the bottom-right corner of a lens.
/// Drag it to resize with one finger.
private struct ResizeHandle: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.55))
                .frame(width: 28, height: 28)
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Single Blur Lens View

private struct BlurLensView: View {
    let lens: BlurLens
    let isSelected: Bool
    let containerSize: CGSize

    let onMoveEnd: (CGPoint) -> Void
    let onResize:  (CGSize)  -> Void
    let onRemove:  () -> Void
    let onSelect:  () -> Void

    // Live gesture state — stored here so the view renders responsively
    // without waiting for the manager round-trip.
    @State private var livePosition: CGPoint? = nil   // set during drag
    @State private var pinchScale:   CGFloat  = 1.0   // set during pinch
    @State private var handleDelta:  CGSize   = .zero // set during handle drag

    // ── Derived values ──────────────────────────────────────────────────────

    private var isCircular: Bool { lens.preset.isCircular }

    private var committedSize: CGSize {
        lens.isFullScreen ? containerSize : lens.size
    }

    /// Size reflected while a pinch is in progress.
    private var pinchLiveSize: CGSize { clamp(committedSize.scaled(by: pinchScale)) }

    /// Size reflected while the corner handle is being dragged.
    private var handleLiveSize: CGSize {
        let dw = handleDelta.width
        let dh = handleDelta.height
        let delta = isCircular
            ? CGSize(width: max(dw, dh), height: max(dw, dh))
            : CGSize(width: dw, height: dh)
        return clamp(CGSize(
            width:  committedSize.width  + delta.width,
            height: committedSize.height + delta.height
        ))
    }

    /// The size we actually render at any given moment.
    private var effectiveSize: CGSize {
        if lens.isFullScreen     { return containerSize }
        if pinchScale != 1.0     { return pinchLiveSize }
        if handleDelta != .zero  { return handleLiveSize }
        return committedSize
    }

    /// Centre position, possibly overridden during a live drag.
    private var effectivePosition: CGPoint {
        livePosition ?? (lens.isFullScreen
            ? CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
            : lens.position)
    }

    private func clamp(_ s: CGSize) -> CGSize {
        let minD: CGFloat = 40
        let maxW = max(containerSize.width,  80)
        let maxH = max(containerSize.height, 80)
        var w = min(max(s.width,  minD), maxW)
        var h = min(max(s.height, minD), maxH)
        if isCircular { let d = max(w, h); w = d; h = d }
        return CGSize(width: w, height: h)
    }

    private var lensShape: AnyShape {
        isCircular
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // ── Body ────────────────────────────────────────────────────────────────

    var body: some View {
        ZStack {

            // ── 1. Blur surface ─────────────────────────────────────────────
            SystemBlurView(style: .systemUltraThinMaterial)
                .frame(width: effectiveSize.width, height: effectiveSize.height)
                .clipShape(lensShape)
                .overlay(
                    lensShape.stroke(
                        isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.35),
                        lineWidth: isSelected ? 2.5 : 1.5
                    )
                )
                // "Drag · Pinch" hint inside the lens when selected
                .overlay(
                    Group {
                        if isSelected && !lens.isFullScreen {
                            Label("Drag  ·  Pinch to resize", systemImage: "hand.draw")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.65))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                    }
                )
                .shadow(color: .black.opacity(0.28), radius: 8, x: 0, y: 4)

                // Tap to select / deselect
                .onTapGesture { onSelect() }

                // ── Drag-to-move ────────────────────────────────────────────
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { v in
                            guard !lens.isFullScreen else { return }
                            livePosition = CGPoint(
                                x: lens.position.x + v.translation.width,
                                y: lens.position.y + v.translation.height
                            )
                        }
                        .onEnded { v in
                            guard !lens.isFullScreen else { return }
                            let final = CGPoint(
                                x: lens.position.x + v.translation.width,
                                y: lens.position.y + v.translation.height
                            )
                            livePosition = nil
                            onMoveEnd(final)
                        }
                )

                // ── Pinch-to-resize (two fingers) ───────────────────────────
                .gesture(
                    MagnificationGesture()
                        .onChanged { scale in
                            guard !lens.isFullScreen else { return }
                            pinchScale = scale
                        }
                        .onEnded { _ in
                            guard !lens.isFullScreen else { return }
                            onResize(pinchLiveSize)
                            pinchScale = 1.0
                        }
                )

            // ── 2. Close button — top-right ─────────────────────────────────
            if isSelected && !lens.isFullScreen {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white, Color.black.opacity(0.7))
                        .shadow(radius: 3)
                }
                // Offset from ZStack centre to top-right corner of the blur frame
                .offset(
                    x:  effectiveSize.width  / 2 + 4,
                    y: -effectiveSize.height / 2 - 4
                )
            }

            // ── 3. Resize handle — bottom-right ─────────────────────────────
            if !lens.isFullScreen {
                ResizeHandle()
                    // Offset from ZStack centre to bottom-right corner
                    .offset(
                        x: effectiveSize.width  / 2 + 4,
                        y: effectiveSize.height / 2 + 4
                    )
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { v in
                                let dw = v.translation.width
                                let dh = v.translation.height
                                handleDelta = isCircular
                                    ? CGSize(width: max(dw, dh), height: max(dw, dh))
                                    : CGSize(width: dw, height: dh)
                                onResize(handleLiveSize)
                            }
                            .onEnded { _ in
                                onResize(handleLiveSize)
                                handleDelta = .zero
                            }
                    )
                    // Generous hit target
                    .contentShape(Circle().size(CGSize(width: 48, height: 48)))
            }
        }
        // spring on selection change only — not on drag (that's already live)
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isSelected)
        // Place this ZStack so its centre is at effectivePosition
        .position(effectivePosition)
    }
}

// MARK: - Blur Lens Overlay

/// Drop this into a ZStack above all content you want to blur.
/// It owns the placement gesture and renders every active BlurLens.
public struct BlurLensOverlayView: View {
    @ObservedObject var blurManager: BlurLensManager
    var containerSize: CGSize

    @State private var selectedLensID: UUID? = nil

    public init(blurManager: BlurLensManager, containerSize: CGSize) {
        self.blurManager = blurManager
        self.containerSize = containerSize
    }

    public var body: some View {
        ZStack {

            // ── Placement mode ──────────────────────────────────────────────
            if blurManager.isBlurModeActive {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard let preset = blurManager.pendingPreset else { return }
                        blurManager.placeLens(preset: preset, at: location, containerSize: containerSize)
                        blurManager.deactivateBlurMode()
                        selectedLensID = blurManager.lenses.last?.id
                    }
                    .overlay(placementHint)
            }

            // ── Placed lenses ───────────────────────────────────────────────
            ForEach(blurManager.lenses) { lens in
                BlurLensView(
                    lens: lens,
                    isSelected: selectedLensID == lens.id,
                    containerSize: containerSize,
                    onMoveEnd: { blurManager.move(lens: lens, to: $0) },
                    onResize:  { blurManager.resize(lens: lens, to: $0) },
                    onRemove:  {
                        blurManager.remove(lens: lens)
                        if selectedLensID == lens.id { selectedLensID = nil }
                    },
                    onSelect: {
                        selectedLensID = (selectedLensID == lens.id) ? nil : lens.id
                    }
                )
            }
        }
        // Deselect on background tap
        .onTapGesture {
            if !blurManager.isBlurModeActive { selectedLensID = nil }
        }
    }

    // MARK: Placement hint overlay
    private var placementHint: some View {
        VStack(spacing: 10) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.white.opacity(0.8))
            VStack(spacing: 4) {
                Text("Tap to place")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                Text(blurManager.pendingPreset?.rawValue ?? "Blur Lens")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Divider().frame(width: 120).overlay(Color.white.opacity(0.3))
            HStack(spacing: 16) {
                Label("Drag to move", systemImage: "hand.draw")
                Label("Pinch to resize", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.65))
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .shadow(radius: 10)
    }
}

// MARK: - Blur Toolbar Section

/// A compact row of blur-preset buttons that slots into DrawingToolbarView.
public struct BlurToolbarSection: View {
    @ObservedObject var blurManager: BlurLensManager

    public init(blurManager: BlurLensManager) {
        self.blurManager = blurManager
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Label Header
            HStack(spacing: 4) {
                Image(systemName: "aqi.medium")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(blurManager.isBlurModeActive ? Color.cyan : Color.secondary)
                Text("Blur")
                    .font(.caption.bold())
                    .foregroundStyle(blurManager.isBlurModeActive ? Color.cyan : Color.secondary)
            }
            
            // Dynamic, evenly spaced wrapping layout
            // Defines a 5-column layout where each column expands equally to fill the space
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                alignment: .center,
                spacing: 12
            ) {
                ForEach(BlurLensPreset.allCases) { preset in
                    blurPresetButton(preset)
                }

                // Remove-all trash button fills the last slot in the layout grid seamlessly
                Button(action: {
                    blurManager.removeAll()
                    blurManager.deactivateBlurMode()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(blurManager.lenses.isEmpty
                                         ? Color.secondary.opacity(0.4) : Color.red)
                        .frame(width: 30, height: 30)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .disabled(blurManager.lenses.isEmpty)
                .accessibilityLabel("Remove all blur lenses")
            }
        }
    }


    @ViewBuilder
    private func blurPresetButton(_ preset: BlurLensPreset) -> some View {
        let isActive = blurManager.isBlurModeActive && blurManager.pendingPreset == preset

        Button(action: {
            isActive ? blurManager.deactivateBlurMode()
                     : blurManager.activateBlurMode(preset: preset)
        }) {
            VStack(spacing: 3) {
                Image(systemName: preset.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isActive ? Color.white : Color.primary)
                Text(shortLabel(preset))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isActive ? Color.white : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 52, height: 40)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isActive ? Color.cyan : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isActive ? Color.cyan.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)
        }
        .accessibilityLabel("Blur lens: \(preset.rawValue)")
    }

    private func shortLabel(_ preset: BlurLensPreset) -> String {
        switch preset {
        case .smallCircle: return "Small Circle"
        case .bigCircle:   return "Large Circle"
        case .rectangle:   return "Rectangle"
        case .square:      return "Square"
        case .fullScreen:  return "Full Screen"
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @StateObject var blurManager = BlurLensManager()
    VStack {
        Spacer()
        BlurToolbarSection(blurManager: blurManager)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .padding()
    }
    .background(
        LinearGradient(
            colors: [.indigo, .purple, .pink],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    )
}


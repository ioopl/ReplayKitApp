import SwiftUI
import Combine

// MARK: - Blur Lens Preset

/// The five selectable blur presets available in the toolbar.
public enum BlurLensPreset: String, CaseIterable, Identifiable {
    case smallCircle  = "Small Circle"
    case bigCircle    = "Big Circle"
    case rectangle    = "Rectangle"
    case square       = "Square"
    case fullScreen   = "Full Screen"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .smallCircle: 
            return "circle"
        case .bigCircle:   
            return "circle.fill"
        case .rectangle:   
            return "rectangle"
        case .square:      
            return "square"
        case .fullScreen:  
            return "rectangle.fill.on.rectangle.fill"
        }
    }

    /// Default size for the lens when first placed, in logical points.
    public var defaultSize: CGSize {
        switch self {
        case .smallCircle:
            return CGSize(width: 100, height: 100)
        case .bigCircle:
            return CGSize(width: 220, height: 220)
        case .rectangle:
            return CGSize(width: 260, height: 140)
        case .square:
            return CGSize(width: 180, height: 180)
        case .fullScreen:
            return CGSize(width: 0,   height: 0)   // full screen — special-cased
        }
    }

    /// Whether the shape should be clipped to a circle.
    public var isCircular: Bool {
        switch self {
        case .smallCircle, .bigCircle:
            return true
        default: return false
        }
    }
}

// MARK: - Blur Lens Model

/// A single placed blur lens on the canvas.
public struct BlurLens: Identifiable {
    public let id = UUID()
    public var preset: BlurLensPreset
    /// Centre position in the parent coordinate space.
    public var position: CGPoint
    /// Current size (can be changed via pinch-to-resize in the future).
    public var size: CGSize
    /// UIBlurEffect intensity expressed as a blur radius (used with Metal/CIFilter).
    /// Values 20–80 feel like "super blurry" without being completely flat.
    public var blurRadius: CGFloat = 40

    public var isFullScreen: Bool { preset == .fullScreen }
}

// MARK: - Blur Lens Manager

/// Manages all active blur lenses. Shared via `@ObservedObject` across views.
@MainActor
public class BlurLensManager: ObservableObject {

    public static let shared = BlurLensManager()

    @Published public var lenses: [BlurLens] = []
    /// The preset that will be used the next time the user taps the canvas to place a lens.
    @Published public var pendingPreset: BlurLensPreset? = nil
    /// Whether blur-placement mode is active (i.e. next tap → place lens).
    @Published public var isBlurModeActive: Bool = false

    public init() {}

    // MARK: Placement

    /// Place a new lens of the given preset centred at `position` inside `containerSize`.
    public func placeLens(preset: BlurLensPreset, at position: CGPoint, containerSize: CGSize) {
        if preset == .fullScreen {
            // Full-screen lens: centred, fills the container.
            let lens = BlurLens(
                preset: preset,
                position: CGPoint(x: containerSize.width / 2, y: containerSize.height / 2),
                size: containerSize
            )
            // Remove any existing full-screen lens (only one at a time makes sense).
            lenses.removeAll { $0.preset == .fullScreen }
            lenses.append(lens)
        } else {
            let lens = BlurLens(preset: preset, position: position, size: preset.defaultSize)
            lenses.append(lens)
        }
    }

    // MARK: Mutation

    public func move(lens: BlurLens, to newPosition: CGPoint) {
        guard let idx = lenses.firstIndex(where: { $0.id == lens.id }) else { return }
        lenses[idx].position = newPosition
    }

    public func resize(lens: BlurLens, to newSize: CGSize) {
        guard let idx = lenses.firstIndex(where: { $0.id == lens.id }) else { return }
        let minDim: CGFloat = 40
        let maxDim: CGFloat = 800
        var w = min(max(newSize.width,  minDim), maxDim)
        var h = min(max(newSize.height, minDim), maxDim)
        // Keep circles square
        if lens.preset.isCircular { let s = max(w, h); w = s; h = s }
        lenses[idx].size = CGSize(width: w, height: h)
    }

    public func remove(lens: BlurLens) {
        lenses.removeAll { $0.id == lens.id }
    }

    public func removeAll() {
        lenses.removeAll()
    }

    // MARK: Mode helpers

    public func activateBlurMode(preset: BlurLensPreset) {
        pendingPreset = preset
        isBlurModeActive = true
    }

    public func deactivateBlurMode() {
        pendingPreset = nil
        isBlurModeActive = false
    }
}

import SwiftUI
import PencilKit
import Combine

// MARK: - Drawing Types

public enum DrawingToolType: String, CaseIterable, Identifiable {
    case pen = "Pen"
    case highlighter = "Highlighter"
    case pencil = "Pencil"
    case eraser = "Eraser"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .pen: return "paintbrush.pointed.fill"
        case .highlighter: return "highlighter"
        case .pencil: return "pencil"
        case .eraser: return "eraser.fill"
        }
    }
}

public enum DrawingColor: String, CaseIterable, Identifiable {
    case yellow = "Yellow"
    case red = "Red"
    case cyan = "Cyan"
    case green = "Green"
    case white = "White"
    case black = "Black"
    
    public var id: String { rawValue }
    
    public var uiColor: UIColor {
        switch self {
        case .yellow: return UIColor(red: 1.0, green: 0.88, blue: 0.0, alpha: 1.0)
        case .red: return UIColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)
        case .cyan: return UIColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 1.0)
        case .green: return UIColor(red: 0.2, green: 0.85, blue: 0.35, alpha: 1.0)
        case .white: return .white
        case .black: return .black
        }
    }
    
    public var swiftUIColor: Color {
        Color(uiColor: self.uiColor)
    }
}

public enum DrawingBackgroundMode: String, CaseIterable, Identifiable {
    case transparentOverlay = "Overlay"
    case whiteboard = "Whiteboard"
    case blackboard = "Blackboard"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .transparentOverlay: return "square.dashed"
        case .whiteboard: return "square.fill"
        case .blackboard: return "rectangle.fill"
        }
    }
}

// MARK: - Drawing Service Protocol

public protocol DrawingServiceProtocol: AnyObject {
    var isDrawingActive: Bool { get set }
    var activeTool: DrawingToolType { get set }
    var strokeColor: DrawingColor { get set }
    var strokeWidth: CGFloat { get set }
    var backgroundMode: DrawingBackgroundMode { get set }
    var canUndo: Bool { get }
    var canRedo: Bool { get }
    var hasStrokes: Bool { get }
    var lastSnapshot: UIImage? { get set }
    
    func undo()
    func redo()
    func clear()
    func captureSnapshot(size: CGSize) -> UIImage?
    func registerCanvas(_ canvas: PKCanvasView)
}

// MARK: - Drawing Canvas Manager (MVVM Service)

@MainActor
public class DrawingCanvasManager: ObservableObject, DrawingServiceProtocol {
    public static let shared = DrawingCanvasManager()

    // These values are intentionally stable because the host app and the
    // Broadcast Upload Extension are separate targets/processes.
    public static let appGroupID = "group.com.apkia.replaykitapp.shared"
    public static let overlayDirectoryName = "ScreenDrawing"
    public static let overlayFileName = "drawing-overlay.png"
    public static let overlayAvailableKey = "screenDrawing.overlayAvailable"
    public static let overlayTimestampKey = "screenDrawing.overlayTimestamp"
    public static let hostAppInBackgroundKey = "screenDrawing.hostAppInBackground"
    
    @Published public var isDrawingActive: Bool = false
    @Published public var activeTool: DrawingToolType = .pen {
        didSet { updateCanvasTool() }
    }
    @Published public var strokeColor: DrawingColor = .yellow {
        didSet { updateCanvasTool() }
    }
    @Published public var strokeWidth: CGFloat = 5.0 {
        didSet { updateCanvasTool() }
    }
    @Published public var backgroundMode: DrawingBackgroundMode = .transparentOverlay
    @Published public var canUndo: Bool = false
    @Published public var canRedo: Bool = false
    @Published public var hasStrokes: Bool = false
    @Published public var lastSnapshot: UIImage?
    
    public weak var canvasView: PKCanvasView?
    
    public init() {}
    
    public func registerCanvas(_ canvas: PKCanvasView) {
        self.canvasView = canvas
        updateCanvasTool()
        updateUndoRedoState()
    }
    
    public func updateCanvasTool() {
        guard let canvas = canvasView else { return }
        switch activeTool {
        case .pen:
            canvas.tool = PKInkingTool(.pen, color: strokeColor.uiColor, width: strokeWidth)
        case .highlighter:
            canvas.tool = PKInkingTool(.marker, color: strokeColor.uiColor.withAlphaComponent(0.65), width: strokeWidth * 2.2)
        case .pencil:
            canvas.tool = PKInkingTool(.pencil, color: strokeColor.uiColor, width: strokeWidth)
        case .eraser:
            canvas.tool = PKEraserTool(.vector)
        }
    }
    
    public func updateUndoRedoState() {
        guard let canvas = canvasView else {
            canUndo = false
            canRedo = false
            hasStrokes = false
            return
        }
        canUndo = canvas.undoManager?.canUndo ?? false
        canRedo = canvas.undoManager?.canRedo ?? false
        hasStrokes = !canvas.drawing.strokes.isEmpty
    }
    
    public func undo() {
        canvasView?.undoManager?.undo()
        updateUndoRedoState()
    }
    
    public func redo() {
        canvasView?.undoManager?.redo()
        updateUndoRedoState()
    }
    
    public func clear() {
        canvasView?.drawing = PKDrawing()
        updateUndoRedoState()
        lastSnapshot = nil
        syncSnapshotToAppGroup(nil)
    }
    
    public func captureSnapshot(size: CGSize = CGSize(width: 640, height: 480)) -> UIImage? {
        guard let canvas = canvasView else {
            return lastSnapshot
        }
        
        let bounds = canvas.bounds.size.width > 0 && canvas.bounds.size.height > 0 ? canvas.bounds : CGRect(origin: .zero, size: size)
        
        // If drawing has no strokes and no prior snapshot, return nil
        if canvas.drawing.strokes.isEmpty {
            return lastSnapshot
        }
        
        let scale = UIScreen.main.scale
        let image = canvas.drawing.image(from: bounds, scale: scale)
        self.lastSnapshot = image
        syncSnapshotToAppGroup(image)
        return image
    }

    /// Publishes the current transparent drawing to the App Group. The PNG is
    /// replaced atomically so the extension never reads a partially-written
    /// image while it is processing a video frame.
    public func syncSnapshotToAppGroup(_ snapshot: UIImage?) {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let containerURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Self.appGroupID
              ) else { return }

        let directoryURL = containerURL.appendingPathComponent(Self.overlayDirectoryName, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent(Self.overlayFileName)

        guard let snapshot, let pngData = snapshot.pngData() else {
            try? FileManager.default.removeItem(at: fileURL)
            defaults.set(false, forKey: Self.overlayAvailableKey)
            defaults.removeObject(forKey: Self.overlayTimestampKey)
            defaults.synchronize()
            return
        }

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try pngData.write(to: fileURL, options: [.atomic])
            defaults.set(true, forKey: Self.overlayAvailableKey)
            defaults.set(Date().timeIntervalSince1970, forKey: Self.overlayTimestampKey)
            defaults.synchronize()
        } catch {
            print("Drawing overlay App Group sync failed: \(error)")
        }
    }

    /// Called from scenePhase changes. The extension uses this to know whether
    /// the drawing is already present in the live display compositor.
    public func updateHostAppBackgroundState(_ isBackground: Bool) {
        UserDefaults(suiteName: Self.appGroupID)?.set(
            isBackground,
            forKey: Self.hostAppInBackgroundKey
        )
        UserDefaults(suiteName: Self.appGroupID)?.synchronize()
    }
}

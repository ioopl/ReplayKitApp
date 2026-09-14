import UIKit
import PencilKit
@testable import ReplayKitApp

class MockDrawingService: DrawingServiceProtocol {
    var isDrawingActive: Bool = false
    var activeTool: DrawingToolType = .pen
    var strokeColor: DrawingColor = .yellow
    var strokeWidth: CGFloat = 5.0
    var backgroundMode: DrawingBackgroundMode = .transparentOverlay
    var canUndo: Bool = false
    var canRedo: Bool = false
    var hasStrokes: Bool = false
    var lastSnapshot: UIImage?
    
    var undoCalled = false
    var redoCalled = false
    var clearCalled = false
    var snapshotCaptured = false
    
    func undo() {
        undoCalled = true
    }
    
    func redo() {
        redoCalled = true
    }
    
    func clear() {
        clearCalled = true
        hasStrokes = false
        lastSnapshot = nil
    }
    
    func captureSnapshot(size: CGSize) -> UIImage? {
        snapshotCaptured = true
        if let existing = lastSnapshot {
            return existing
        }
        // Generate a small dummy image for testing
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            UIColor.yellow.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        lastSnapshot = img
        return img
    }
    
    func registerCanvas(_ canvas: PKCanvasView) {
        // No-op for mock
    }
}

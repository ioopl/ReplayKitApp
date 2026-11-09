import SwiftUI
import PencilKit
import WebKit

/**
 - `PencilCanvasRepresentable`: `UIViewRepresentable` wrapping `PKCanvasView` configured with `.anyInput` for immediate finger and stylus support.

 */
// MARK: - PencilKit Canvas Representable

public struct PencilCanvasRepresentable: UIViewRepresentable {
    @ObservedObject var manager: DrawingCanvasManager
    var isInteractionEnabled: Bool
    
    public init(manager: DrawingCanvasManager, isInteractionEnabled: Bool = true) {
        self.manager = manager
        self.isInteractionEnabled = isInteractionEnabled
    }
    
    public func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator
        canvasView.isUserInteractionEnabled = isInteractionEnabled
        
        // Disable scroll bouncing on the canvas so drawing is crisp
        canvasView.bounces = false
        canvasView.alwaysBounceVertical = false
        canvasView.alwaysBounceHorizontal = false
        
        manager.registerCanvas(canvasView)
        return canvasView
    }
    
    public func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.isUserInteractionEnabled = isInteractionEnabled
        if manager.canvasView == nil {
            manager.registerCanvas(uiView)
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager)
    }
    
    public class Coordinator: NSObject, PKCanvasViewDelegate {
        let manager: DrawingCanvasManager
        
        init(manager: DrawingCanvasManager) {
            self.manager = manager
        }
        
        public func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            manager.updateUndoRedoState()
            _ = manager.captureSnapshot()
        }
    }
}

import SwiftUI
import PencilKit

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

// MARK: - Floating Telestrator Toolbar

public struct DrawingToolbarView: View {
    @ObservedObject var manager: DrawingCanvasManager
    @Binding var isDrawingMode: Bool
    @State private var isCollapsed: Bool = false
    @State private var showSettings: Bool = false
    
    public init(manager: DrawingCanvasManager, isDrawingMode: Binding<Bool>) {
        self.manager = manager
        self._isDrawingMode = isDrawingMode
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            if isCollapsed {
                collapsedButton
            } else {
                expandedToolbar
            }
        }
        .padding(8)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isCollapsed)
        .animation(.easeInOut(duration: 0.2), value: isDrawingMode)
    }
    
    // Collapsed floating bubble
    private var collapsedButton: some View {
        Button(action: { isCollapsed = false }) {
            HStack(spacing: 6) {
                Image(systemName: isDrawingMode ? "pencil.tip.crop.circle.fill" : "hand.draw.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                
                Text(isDrawingMode ? "Draw" : "Touch")
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isDrawingMode ? Color.blue : Color.gray)
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
            )
        }
        .accessibilityLabel("Expand Drawing Toolbar")
    }
    
    // Expanded Toolbar
    private var expandedToolbar: some View {
        VStack(spacing: 10) {
            // Row 1: Primary Controls (Mode, Tools, Undo/Redo, Actions)
            HStack(spacing: 8) {
                // Toggle Draw vs Touch/Interact
                Button(action: {
                    isDrawingMode.toggle()
                }) {
                    Label(isDrawingMode ? "Drawing" : "Touch", systemImage: isDrawingMode ? "pencil.line" : "hand.tap.fill")
                        .font(.caption.bold())
                        .foregroundColor(isDrawingMode ? .white : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isDrawingMode ? Color.blue : Color(.systemGray5))
                        .cornerRadius(8)
                }
                .accessibilityLabel(isDrawingMode ? "Drawing mode active. Tap for touch mode" : "Touch mode active. Tap for drawing mode")
                
                Divider()
                    .frame(height: 24)
                
                // Tool Pickers (Pen, Highlighter, Pencil, Eraser)
                ForEach(DrawingToolType.allCases) { tool in
                    Button(action: {
                        manager.activeTool = tool
                        if !isDrawingMode { isDrawingMode = true }
                    }) {
                        Image(systemName: tool.iconName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(manager.activeTool == tool && isDrawingMode ? .white : .primary)
                            .frame(width: 32, height: 32)
                            .background(manager.activeTool == tool && isDrawingMode ? Color.purple : Color.clear)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("\(tool.rawValue) tool")
                }
                
                Divider()
                    .frame(height: 24)
                
                // Undo / Redo
                Button(action: { manager.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(manager.canUndo ? .primary : .secondary.opacity(0.4))
                }
                .disabled(!manager.canUndo)
                .accessibilityLabel("Undo")
                
                Button(action: { manager.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(manager.canRedo ? .primary : .secondary.opacity(0.4))
                }
                .disabled(!manager.canRedo)
                .accessibilityLabel("Redo")
                
                // Clear Canvas
                Button(action: { manager.clear() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(manager.hasStrokes ? .red : .secondary.opacity(0.4))
                }
                .disabled(!manager.hasStrokes)
                .accessibilityLabel("Clear canvas")
                
                Spacer(minLength: 0)
                
                // Collapse button
                Button(action: { isCollapsed = true }) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Minimize toolbar")
            }
            
            // Row 2: Color Palette, Stroke Width, and Background Mode
            HStack(spacing: 8) {
                // Color Swatches
                ForEach(DrawingColor.allCases) { color in
                    Button(action: {
                        manager.strokeColor = color
                        if manager.activeTool == .eraser {
                            manager.activeTool = .pen
                        }
                    }) {
                        Circle()
                            .fill(color.swiftUIColor)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: manager.strokeColor == color ? 2.5 : 0.5)
                            )
                            .scaleEffect(manager.strokeColor == color ? 1.15 : 1.0)
                    }
                    .accessibilityLabel("\(color.rawValue) color")
                }
                
                Divider()
                    .frame(height: 20)
                
                // Stroke Width options (Thin, Medium, Thick)
                HStack(spacing: 4) {
                    strokeWidthButton(width: 2.5, iconSize: 4)
                    strokeWidthButton(width: 5.0, iconSize: 7)
                    strokeWidthButton(width: 10.0, iconSize: 11)
                }
                
                Spacer(minLength: 0)
                
                // Background Mode Picker
                Menu {
                    ForEach(DrawingBackgroundMode.allCases) { mode in
                        Button(action: { manager.backgroundMode = mode }) {
                            Label(mode.rawValue, systemImage: mode.iconName)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: manager.backgroundMode.iconName)
                            .font(.caption)
                        Text(manager.backgroundMode.rawValue)
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
                }
                .accessibilityLabel("Canvas background mode")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
        )
    }
    
    private func strokeWidthButton(width: CGFloat, iconSize: CGFloat) -> some View {
        Button(action: {
            manager.strokeWidth = width
        }) {
            Circle()
                .fill(manager.strokeWidth == width ? Color.primary : Color.secondary.opacity(0.4))
                .frame(width: iconSize, height: iconSize)
                .frame(width: 22, height: 22)
                .background(manager.strokeWidth == width ? Color.primary.opacity(0.12) : Color.clear)
                .clipShape(Circle())
        }
        .accessibilityLabel("\(Int(width))pt stroke width")
    }
}

// MARK: - Drawing Canvas Container View

public struct DrawingCanvasContainerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var manager: DrawingCanvasManager
    @Binding var isDrawingMode: Bool
    var isBroadcasting: Bool
    
    public init(
        manager: DrawingCanvasManager = .shared,
        isDrawingMode: Binding<Bool>,
        isBroadcasting: Bool
    ) {
        self.manager = manager
        self._isDrawingMode = isDrawingMode
        self.isBroadcasting = isBroadcasting
    }
    
    public var body: some View {
        ZStack {
            // Background depending on mode
            switch manager.backgroundMode {
            case .transparentOverlay:
                Color.clear
            case .whiteboard:
                Color.white
                    .ignoresSafeArea()
            case .blackboard:
                Color(red: 0.12, green: 0.14, blue: 0.13)
                    .ignoresSafeArea()
            }
            
            // PencilKit Canvas
            PencilCanvasRepresentable(
                manager: manager,
                isInteractionEnabled: isDrawingMode
            )
            .ignoresSafeArea()
            
            // Top live broadcast status banner if broadcasting
            VStack {
                if isBroadcasting {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                            .opacity(isBroadcasting ? 1.0 : 0.4)
                        
                        Text("REC ● Screen Drawing Captured Live")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.75))
                            .overlay(
                                Capsule().stroke(Color.red.opacity(0.6), lineWidth: 1)
                            )
                    )
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                // Floating Toolbar at Bottom
                DrawingToolbarView(
                    manager: manager,
                    isDrawingMode: $isDrawingMode
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
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


#Preview {
    @Previewable
    @State var isDrawing = true
    return DrawingToolbarView(manager: DrawingCanvasManager(), isDrawingMode: $isDrawing)
}

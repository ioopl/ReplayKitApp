# Live Screen Drawing (Telestrator) in System-Wide Broadcast Recording

Note: A telestrator is an electronic device or software tool that lets an operator draw freehand sketches or shapes directly over a moving or still video image. [source] (https://en.wikipedia.org/wiki/Telestrator)

## Enable real-time drawing and telestration on the screen during a System-Wide Screen Broadcast, allowing users to annotate, sketch diagrams, highlight UI, and draw notes while the broadcast recording captures every stroke live into the MP4 recording.

## Limitations : Note the drawing toolbar cannot appear over Outlook, Photos, or other apps on iOS. Only the system-owned app is interactive; ReplayKitApp is no longer on the display. However the compositing gate is added so the overlay activates during both .inactive and .background transitions, which is when iOS switches away from ReplayKitApp.
---

## 1. iOS Screen Capture Architecture

- **ReplayKit Compositor**: `RPBroadcastSampleHandler` captures whatever pixels are rendered on the physical device display.
- **Sandboxing Boundary**: Apple's iOS security sandbox strictly prevents third-party apps from drawing an interactive floating window *over other third-party apps* or the iOS SpringBoard (unlike Android).
- **In-App Telestrator & Presentation Board**: The drawing experience is implemented as an interactive **Telestrator & Whiteboard Overlay** within the System-Wide Broadcast interface.
- **Real-Time Capture**: Every stroke drawn on screen with finger or Apple Pencil is captured at 60 FPS directly into `broadcast.mp4`.
- **Simulator Synthesis**: In the Simulator, `simulateBroadcastEnded()` and `createSampleVideoFile()` rasterize the user's drawing snapshot onto the synthesized video frames so the feature is 100% testable end-to-end on both Simulator and physical devices.

---

## 2. Architecture & MVVM Dependency Injection

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                       SystemWideScreenBroadcastView                         │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     DrawingCanvasContainerView                        │  │
│  │  - PencilKit (PKCanvasView) with Apple Pencil & Finger Touch support  │  │
│  │  - Modes: Transparent Overlay (over app) | Whiteboard | Blackboard    │  │
│  │  - Pass-through toggle (Draw Mode vs. Touch/Interact Mode)            │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     Floating Telestrator Toolbar                      │  │
│  │  - Pen, Highlighter, Pencil, Vector Eraser                           │  │
│  │  - Color palette (Neon Yellow, Red, Electric Blue, Green, White)      │  │
│  │  - Stroke thickness (Thin, Medium, Bold)                              │  │
│  │  - Undo, Redo, Clear All                                              │  │
│  │  - Minimize / Expand floating bubble                                  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     Live Broadcast Status Banner                      │  │
│  │  - "🔴 REC ● Live Screen Drawing Active" (Visible when broadcasting)  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
            ┌──────────────────────────┴──────────────────────────┐
            ▼                                                     ▼
┌──────────────────────────────┐              ┌───────────────────────────────┐
│     Device Capture (Real)    │              │      Simulator Synthesis      │
│  ReplayKit compositor grabs  │              │  Rasterizes PKDrawing snapshot│
│  entire screen @ 60 FPS into │              │  into generated MP4 frames in │
│  SampleHandler broadcast.mp4 │              │  createSampleVideoFile()      │
└──────────────────────────────┘              └───────────────────────────────┘
                                       │
                                       ▼
                     ┌───────────────────────────────────┐
                     │       PostSessionSummaryView      │
                     │  - Displays Drawing Annotation    │
                     │    artifact in Session Artifacts  │
                     └───────────────────────────────────┘
```

---

## 3. Implemented Components

1. **`DrawingCanvasManager.swift`**:
   - Manages PencilKit state, active tool (`.pen`, `.highlighter`, `.pencil`, `.eraser`), color selection, stroke width, background modes, undo/redo stack, and snapshot rendering.
2. **`DrawingCanvasView.swift`**:
   - `PencilCanvasRepresentable`: `UIViewRepresentable` wrapping `PKCanvasView` configured with `.anyInput` for immediate finger and stylus support.
   - `DrawingToolbarView`: Floating, dockable, collapsible toolbar with tools, swatches, thickness, undo/redo, clear, and background modes.
   - `DrawingCanvasContainerView`: Fullscreen container supporting Transparent Overlay, Whiteboard, and Blackboard with live broadcast status.
3. **`SystemWideScreenBroadcastViewModel.swift`**:
   - Injected with `DrawingServiceProtocol`.
   - Captures drawing snapshot on session completion.
   - Composites drawing into video frames in `createSampleVideoFile()`.
4. **`SystemWideScreenBroadcastView.swift`**:
   - Adds floating/toolbar drawing toggle button.
   - Live Screen Telestrator card in dashboard.
   - Embeds drawing canvas container.
5. **`PostSessionSummaryView.swift`**:
   - Displays "Screen Drawing Annotations" artifact card under Session Artifacts.
6. **`MockDrawingService.swift` & `ReplayKitAppTests.swift`**:
   - Unit tests covering DI, drawing state changes, video snapshot synthesis, and buffer clearing.

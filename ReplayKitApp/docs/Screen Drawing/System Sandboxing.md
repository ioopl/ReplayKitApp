# System Sandboxing

Q: When I switch to different App while System Wide Screen Recording to do the Screen record the newly added Screen Drawing is not there?

---

## 1. Why the Drawing Disappears When Switching Apps

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│                              iOS DISPLAY BUFFER                              │
├──────────────────────────────────────┬───────────────────────────────────────┤
│    Inside ReplayKitApp (Active)      │      Switched to Safari / Other App   │
├──────────────────────────────────────┼───────────────────────────────────────┤
│  [ ReplayKitApp UI ]                 │  [ Safari UI ]                        │
│  + [ PencilKit Drawing Canvas ]      │  (Safari owns 100% of the screen)     │
│                                      │                                       │
│  👉 ReplayKit captures both          │  👉 ReplayKit captures Safari only;   │
│     app UI & your drawing.           │     ReplayKitApp is suspended in BG.  │
└──────────────────────────────────────┴───────────────────────────────────────┘
```

- **1. Strict iOS Sandboxing** (No "Draw Over Other Apps" on iOS):
Unlike Android (which has the SYSTEM_ALERT_WINDOW permission) or macOS, **iOS strictly forbids third-party apps from creating floating windows or touch overlays over other apps or the Home Screen (SpringBoard).**
This restriction is enforced at the kernel/UIKit level to prevent tapjacking, UI spoofing, and keylogging. When you switch to Safari or Settings, that app has exclusive ownership of the display and all touch input.

- **2.The Broadcast Extension is Headless:**
The Broadcast Upload Extension (SampleHandler) runs as a separate background daemon. By Apple’s API design, broadcast extensions are headless—they have no UIWindow and cannot draw pixels onto the physical screen.

- **3.ReplayKit Captures the Literal Screen Framebuffer:**
SampleHandler receives whatever pixels the iOS compositor sends to the display. Because the drawing canvas was part of ReplayKitApp's view hierarchy, when you switch to another app, those pixels are no longer on the screen, so ReplayKit stops capturing them.

---

## 2. Solutions & Workarounds

**Option A: Persistent Video Overlay / Burned-in Annotation (Extension Compositing)**
// Compositing is the post-production process of combining multiple visual elements or images from separate sources into a single, cohesive final frame or scene. [source] (https://www.mythstudio.co.uk/glossary/compositing), [2] (https://natron.readthedocs.io/en/v2.4.2/guide/intro.html)

**How it works:** When we draw on the canvas in ReplayKitApp, the app writes the drawing snapshot to the shared App Group container (group.com.apkia.replaykitapp.shared). 
    SampleHandler reads this image and **burns/composites the drawing directly onto every captured video frame in real time ** even while users are navigating through Safari or other apps!

**Result:** In the exported .mp4 video, your drawing stays visible on top of the other apps, even though you cannot interactively draw while inside Safari.


**Option B: iPadOS Multitasking (Slide Over / Split View)**

**How it works:** On iPad, ReplayKitApp can be opened in **Slide Over** (a floating overlay over any app) or **Split View** (side-by-side).

**Result:** We can draw on the canvas in the floating Slide Over window right next to Safari or Keynote, and the System-Wide Broadcast will record both simultaneously.

**Option C: In-App Browser & Document Annotation Mode**

**How it works:** If our goal is recording and annotating web pages, documents, or photos, we can embed a browser (WKWebView) or document viewer inside ReplayKitApp beneath the drawing canvas.

**Result:** You can navigate web pages or documents directly within the app while freely drawing and telestrating over them at 60 FPS.

---

## 3. Recommended Next Step
If would like Option A (having the drawing you made stay burned into the recorded video across other apps via SampleHandler). Implement the App Group image sync and pixel-buffer compositing pipeline in SampleHandler.swift. Lets proceed with that!

To clarify: **Option A (Extension Compositing) is NOT iOS-only—it works on BOTH iPhone (iOS) and iPad (iPadOS).**

Here is why each option was mentioned and how they relate to each other:

---

### The Two Different Problems: *Recording* vs. *Interactivity*

When you leave `ReplayKitApp` to open another app (like Safari), two separate things happen:
1. **The Recording Feed**: The video stops showing your drawing.
2. **The Touch Interaction**: You can no longer touch or draw because touches go to Safari, not `ReplayKitApp`.

Here is how the options address this:

| Feature / Capability | **Option A** (Extension Compositing) | **Option B** (iPadOS Slide Over/Split) | **Option C**(In-App Browser/Viewer) |
| :--- | :--- | :--- | :--- |
| **Supported Devices** | **iPhone & iPad** (iOS & iPadOS) | **iPad Only** (iPadOS) | **iPhone & iPad** (iOS & iPadOS) |
| **Solves Recording?** |  **Yes**: Drawings burn into the MP4 video across all apps. |  **Yes**: Both windows are captured by ReplayKit. |  **Yes**: Web page and drawing are both recorded. |
| **Can You Draw Live While Looking at Web Content?** | ⚠️ Only before/after switching (not while actively touching Safari on iPhone). |  **Yes**: You draw in the Slide Over panel right over/beside Safari. |  **Yes**: The web page is inside the app, with the canvas layered on top. |

---

### Why Option B Was Mentioned for iPad Only

* On an **iPhone (iOS)**, Apple only allows **one full-screen app at a time**. When you open Safari, `ReplayKitApp` is completely minimized to the background. You cannot physically touch or draw new strokes because Safari receives all your finger touches.
* On an **iPad (iPadOS)**, Apple provides **Slide Over** and **Split View**:
  * `ReplayKitApp` can float as a sidebar right over Safari.
  * You can physically draw with an Apple Pencil or finger in the floating window while reading Safari on the rest of the screen, and the System Broadcast records both simultaneously!
  * This is an iPadOS-exclusive system capability, which is why it was called out specifically for iPad.

---

### How Option C Fits In

* If you are on an **iPhone** and want to **browse the web AND draw on it simultaneously**, you cannot do it by switching to the separate Safari app because of the iPhone single-window limit.
* Instead, **Option C** brings the browser inside our app (`WKWebView`). You enter the URL inside `ReplayKitApp`, the web page displays, and the telestrator canvas sits directly on top—giving you live interactive drawing over web pages on iPhone!

---

### Summary & Best Approach

1. **Option A (Extension Compositing)** works on **both iPhone & iPad**. It guarantees that any drawing or annotation you make in `ReplayKitApp` stays burned into the final MP4 recording, even when you switch to other apps.
2. If you want, we can implement **Option A** right now in `SampleHandler.swift` so drawings persist across apps in the video recording.

## System Sandboxing Limitations:
()[./docs/System Sandboxing Limitations.md]
- Correct—the drawing toolbar cannot appear over Outlook, Photos, or other apps on iOS. Only the system-owned app is interactive; ReplayKitApp is no longer on the display.

- The existing drawing remains burned into the recorded MP4.
- Drawing controls are unavailable over external apps due to iOS sandboxing.
- Interactive drawing over another app requires iPad Split View/Slide Over or the future in-app browser mode.

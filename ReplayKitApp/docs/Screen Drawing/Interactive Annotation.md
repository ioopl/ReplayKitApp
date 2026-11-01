# Interactive Annotation

How Teams/Slack-style sharing works:

- The App starts Apple’s system screen broadcast.

- The external App owns the display.

- Any controls visible during sharing belong to the sharing app’s own meeting UI, a system-managed surface, or a separate collaboration canvas.

- They are not arbitrary transparent windows injected over Outlook, Photos, or Safari.

For example, Microsoft Teams’ documented annotation feature is powered by Microsoft Whiteboard. The annotations are a collaboration layer associated with the shared content, not an iOS overlay window owned by Teams over every other app. 

The practical choices therefore mean:

1. Browse & Draw
   The browser and PencilKit canvas are both inside ReplayKitApp. This gives us fully interactive controls and lets the user annotate web content.

2. iPad multitasking
   ReplayKitApp can remain visible beside another app using Split View or another supported multitasking layout. The user draws in our visible app window; it is not floating over the external app.

3. Pre-draw and switch apps
   Existing drawings remain burned into the MP4. The user cannot edit them while another app owns the screen.

4. Teams-style collaboration layer
   We could build a separate annotation/whiteboard experience associated with the recording session, but it still would not be a transparent touch overlay over arbitrary apps.

Apple’s screen capture APIs provide captured video frames to the broadcast pipeline; they do not grant third-party apps arbitrary cross-application window or touch-overlay privileges. 
So the honest product behavior is:
We can annotate external content, but we cannot place our interactive controls directly over arbitrary external iOS apps.

The Browse & Draw implementation is the correct way to offer fully interactive annotation. If the goal is specifically “draw over Outlook while Outlook is foreground,” that requires iPad multitasking with ReplayKitApp still visible, or an Apple-provided/system-managed surface—not a normal third-party overlay.

# 💡 The Broadcast Extension is Headless: The Broadcast Upload Extension (SampleHandler) runs as a separate background daemon. By Apple’s API design, broadcast extensions are headless—they have no UIWindow and cannot draw pixels onto the physical screen.

# ❌ Limitation for Drawing: Yes—this is due to iOS sandboxing. A third-party app cannot display interactive windows, PencilKit controls, or touch overlays above Outlook, Photos, Safari, or the Home Screen. The Broadcast Upload Extension is also headless and cannot create UI.

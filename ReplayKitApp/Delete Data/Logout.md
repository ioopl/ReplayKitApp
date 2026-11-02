# "Logout" in Settings View
- Added a Logout button under the new "Account & Data Management" section at the bottom of SettingsView.
Tapping Logout:
- Removes the current session key from the Keychain (SharedKeychainManager.shared.deleteSymmetricKey()).
- Deactivates drawing state (DrawingCanvasManager.shared.isDrawingActive = false).
- Posts .appUserDidLogout, updating SystemWideScreenBroadcastViewModel to isAuthenticated = false, clearing local buffers, and resetting UI state.
- Automatically dismisses Settings.

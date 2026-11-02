# "Delete Data" with Destruction Dialog & Biometric Authentication

- Added a Delete Data button styled destructively in SettingsView.

- Tapping Delete Data displays a destructive confirmation dialog warning the user that the action cannot be undone and will permanently delete all previous broadcasts, recordings, encrypted frames, and metadata.
- Tapping Continue & Authenticate prompts the user with Face ID / Touch ID / device passcode via LAContext.
Upon successful authentication:
- Purges all stored encrypted sessions, recordings, and drawings via EncryptedFrameStore.shared.deleteAllData().
- Deletes all SwiftData models (FrameEntity and RecordingDocumentEntity).
- Clears all shared App Group UserDefaults recording and ledger metadata.
- Purges Keychain session encryption keys and clears the drawing canvas.
- Posts .appDataDidDelete and .appUserDidLogout, logging the user out and resetting all views.
- Automatically dismisses Settings.

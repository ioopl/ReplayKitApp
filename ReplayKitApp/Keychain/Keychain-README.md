#  KeychainService.swift

## Defines KeychainServiceProtocol and SharedKeychainManager. Includes automatic fallback logic to standard software-based encryption key creation if Secure Enclave entitlements/hardware are missing (e.g., in Simulator or Test runners), resolving OSStatus -34018 errors.


# Security Clarification: App Groups & Keychain Sharing

#  What is "Auth Status" in this context?

The Broadcast Upload Extension (C) is designed for live streaming and cross-app background capture. 
The Broadcast Extension runs as a separate binary target, the main app authenticates the user (e.g., getting a JWT token or stream key), it saves this key/token into NSUserDefaults (with App Groups) or Keychain (Shared Access Group)

## Why are we doing this?
An iOS extension (e.g., the Broadcast Upload Extension) runs in a separate system process with its own sandboxed environment. By default, the Broadcast Extension cannot access the main app's memory, documents, or keychain. To share the 256-bit symmetric encryption session key, we must use:

1. App Groups: Creates a shared sandbox directory on the filesystem between targets.
2. Keychain Access Groups: Enables the keychain database to share entries between targets signed with the same developer certificate.


# Is this secure? Can anyone read it?
Yes. Keychain sharing is locked down at the OS level by Apple's provisioning profiles and code signing. Only targets that:

- Are signed by your Apple Developer Team ID.
- Explicitly declare the exact same App Group / Keychain Access Group in their entitlements. 
- Can access the keys. Other apps on the device cannot access this data.

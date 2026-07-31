As an expert Senior iOS Engineer specializing in systems security and low-latency multimedia streaming. 
I need a fully functional, complete, compilable Swift sample project targeting iOS 17+ that mirrors a production high-security broadcasting client to demo the use of ReplayKit. 
We need to demo 4 things so on Home Screen we need to add this 4 buttons/links to demo each when the user taps on it.  
A) ReplayKit In App Screen Recording Capture, 
B) In App Screen Capture 
C) In App Screen Broadcast 
D) In App Clips Recordings 
Let create separate files for each so we can keep everythign abstracted, you know we follow the MVVM pattern to keep things CLEAN architecture, Separation of Concern, abstratced, UI separate with ViewModel injected into the View and the ViewModel having Service dependency injected- Lets use async/await API and Obserability framework if you think its necessary. Keep everything Unit Tested offcourse.  Lets add UI testing also.

Note : Provide for me a placeholder where we we would add the URL should we need to push the In App Screen Broadcast and In App Clips Recordings I guess - we would need a Broadcast Upload Extension, WebRTC / Secure Socket, Backend Server etc - just put placeholder urls there for now and then we will work on teh backend as second iteration or might just use ArchAI gRPC backend that we build. Do provide me details on would would happen and what would that look like and what needs to be done etc? I mean lets put this in docs/README.md file . 

The project must demonstrate three key architecture principles for an upcoming technical interview:
1. Inter-Process Communication (IPC) & Shared Keychain using App Groups between a Host App and a Broadcast Upload Extension.
2. Secure Enclave interaction utilizing hardware-bound keys and CryptoKit for high-performance symmetric frame encryption.
3. Low-Memory optimization techniques inside a ReplayKit Broadcast Extension to completely prevent out-of-memory (OOM) crashes under a strict 50MB constraint.

Lets structure the response into the following clear files and integration steps:

FILE 1: SharedKeychainManager.swift
A utility class accessible by both targets. It must include:
- A method using SecKeyGeneratePair targeting `kSecAttrTokenIDSecureEnclave` and a configured `kSecAttrAccessGroup`.
- Explicit configuration of `SecAccessControlCreateWithFlags` using `.userPresence` and `.privateKeyUsage`.
- Secure retrieval of a shared 256-bit symmetric session key.

FILE 2: MainAppViewController.swift / SwiftUI View
A basic interface to:
- Trigger the biometrics check via LocalAuthentication to generate or fetch the hardware key.
- Provide a button to trigger an RPSystemBroadcastPickerView to initiate screen capture.

FILE 3: SampleHandler.swift (The Broadcast Upload Extension)
The complete implementation of `RPBroadcastSampleHandler`. It must rigorously implement:
- A custom, serial DispatchQueue managing backpressure via an active frame-dropping flag (`isProcessingFrame`).
- Explicit usage of `autoreleasepool` wrapping the extraction of `CVImageBuffer` and its translation into `Data`.
- High-efficiency `CryptoKit.AES.GCM` serialization of the video frames.
- Inline documentation highlighting exactly how memory allocation is constrained to prevent exceeding the 50MB runtime boundary.

XCODE CONFIGURATION GUIDE:
A precise, bulleted checklist detailing how to set up the App Groups identifier (`group.com.example...`), configure entitlements on both the App and the Extension targets, and correctly configure the Info.plist settings for the Extension (`RPBroadcastProcessMode = KeyFrame`).


I have already added couple of files with the help of Gemini on Web 

```
Part 1: Architecture & Code Implementation

1. Sharing the Keychain via App Groups To pass encryption keys between our Main App and the Broadcast Extension, we must use a shared Keychain Access Group. The key created in the Secure Enclave must also be configured so that the extension can access its cryptographic operations.

KeychainManager.swift file 
```

```
2. ReplayKit Sample Buffer Handling & Memory ManagementInside your SampleHandler (Broadcast Extension), processing video frames without leaking memory is critical due to the 50MB operating limit. We must wrap frame manipulation inside an autoreleasepool and drop frames if the encryption pipeline backs up.

SampleHandler.swift file 
```

```
References: 
I am following these WWDC videos - tutorials 
https://developer.apple.com/videos/play/wwdc2021/10101/
https://developer.apple.com/la/videos/play/wwdc2020/10633/
```

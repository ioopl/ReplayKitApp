# ReplayKit Broadcasting Architecture & Integration Guide

This document outlines the system architecture, security implementation, memory optimization strategies, and backend/gRPC integration plans for the ReplayKit high-security broadcasting client.


```
References: 
Following these WWDC videos - tutorials 
https://developer.apple.com/videos/play/wwdc2021/10101/
https://developer.apple.com/la/videos/play/wwdc2020/10633/
```


---

## 1. System Architecture & IPC (App Groups)

```
┌──────────────────────────────────────┐          ┌──────────────────────────────────────┐
│             Main Host App            │          │      Broadcast Upload Extension      │
│  (UI / Authentication / Controller)  │          │    (Background Frame Processing)     │
├──────────────────────────────────────┤          ├──────────────────────────────────────┤
│  - Secure Enclave Key Gen            │          │  - High-frequency sample capture     │
│  - Symmetric Key derivation          │          │  - Retrieve symmetric key from Group │
│  - Biometric LocalAuthentication     │          │  - Frame-dropping / Backpressure     │
└──────────────────┬───────────────────┘          └──────────────────┬───────────────────┘
                   │                                                 │
                   ▼                                                 ▼
     ┌─────────────────────────────────────────────────────────────────────────────┐
     │                      Shared Keychain (App Access Group)                     │
     │                      [ group.com.example.shared-group ]                     │
     └─────────────────────────────────────────────────────────────────────────────┘
```

The Host App and the Broadcast Extension run as **completely independent processes** with their own memory spaces and sandbox restrictions.
* **App Group Entitlement**: Configured on both targets to share a keychain access group and user defaults.
* **Shared Keychain**: The Host App uses the Secure Enclave to generate a private key that controls access to a shared 256-bit symmetric session key. The Broadcast Extension retrieves this symmetric key securely on-the-fly to encrypt video frames.

---

## 2. Secure Enclave & CryptoKit Encryption

We secure high-performance streaming frames via hardware-accelerated encryption:
1. **Secure Enclave Access Control**:
   * We generate an Elliptic Curve key-pair directly inside the Secure Enclave using `SecKeyGeneratePair` with the attribute `kSecAttrTokenIDSecureEnclave`.
   * Access is protected by biometrics/device passcode via `SecAccessControlCreateWithFlags([.userPresence, .privateKeyUsage], ...)`.
2. **Symmetric Key Wrapping**:
   * Since the Secure Enclave cannot encrypt large streams of data directly due to hardware performance bottlenecks, we generate a high-entropy 256-bit symmetric key (`CryptoKit.SymmetricKey`).
   * This symmetric key is encrypted/decrypted using the Secure Enclave-protected key and stored in the Shared Keychain.
3. **Low-Latency AES-GCM Encryption**:
   * During broadcast, each video frame payload is encrypted using hardware-accelerated AES-GCM (`CryptoKit.AES.GCM`).

---

## 3. Broadcast Extension Low-Memory Optimization (Under 50MB)

ReplayKit Broadcast Extensions are terminated by iOS immediately if memory usage exceeds **50MB**. To prevent out-of-memory (OOM) crashes:
* **Autorelease Pool Scoping**: Wrap frame conversions (`CMSampleBuffer` ➔ `CIImage` ➔ `Data`) in an `autoreleasepool` to force the immediate release of heap allocations before the next frame arrives (30-60 fps).
* **Backpressure Queue**: Use a custom serial `DispatchQueue` with an atomic boolean flag `isProcessingFrame`. If a new frame is received while the previous one is still encrypting, the frame is immediately dropped.
* **Offload Rendering**: Instantiate `CIContext` with options `[.useSoftwareRenderer: false]` to run processing on the GPU, avoiding CPU memory overhead.

---

## 4. gRPC & WebRTC Backend Integration

Option A (In-App Screen Recording) is designed to produce a local, fully finished MP4 video file.

However, in many production scenarios, we don't want a file. Instead, you need the raw video feed in real time. 
So Option B (In-App Raw Frame Capture) is designed for these scenarios:

A) Custom Low-Latency Live Streaming: Sending the screen frames directly over a WebRTC or gRPC pipeline to a streaming platform (like Twitch, YouTube Live, or an enterprise webinar tool).

B) Remote Assistance & Screen Sharing: Real-time collaborative apps (like Zoom, MS Teams, TeamViewer) where an operator needs to see your app screen instantly.

C) Real-time Video Processing: Applying real-time filters, computer vision analytics, or watermarking on the screen feed before transmitting it.

See file ['./In-App Raw Frame Capture/README-B.md'] for details. 


### gRPC HTTP/2 Streaming (ArchAI Backend)
To push video frames over a high-performance gRPC bi-directional stream:
1. Define a Protobuf schema:
   ```protobuf
   syntax = "proto3";
   package broadcast;

   message FramePayload {
     string session_id = 1;
     int64 timestamp_ms = 2;
     bytes encrypted_data = 3; // AES-GCM combined payload
     bytes nonce = 4;
   }

   service BroadcastService {
     rpc StreamFrames(stream FramePayload) returns (StreamResponse);
   }
   ```
2. Integrate Swift gRPC Client (via Swift Package Manager).

3. Establish a streaming connection inside `SampleHandler`:
   * Set up a gRPC channel using TLS client configuration.
   * Call `StreamFrames` to get a streaming writer.
   * Inside `sendToNetwork(_:)`, execute:
     ```swift
     let payload = Broadcast_FramePayload.with {
         $0.sessionId = self.sessionId
         $0.timestampMs = Int64(Date().timeIntervalSince1970 * 1000)
         $0.encryptedData = encryptedData
     }
     _ = self.grpcStream.sendMessage(payload)
     ```

### WebRTC Secure Socket Stream
* **WebRTC**: Feed the decrypted `CVPixelBuffer` directly into a custom `RTCVideoSource` or encode it as H.264/H.265 using `VTCompressionSession` before wrapping it in SRTP.

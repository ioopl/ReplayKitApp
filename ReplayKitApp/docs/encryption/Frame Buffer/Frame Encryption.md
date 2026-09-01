# Are we encrypting each frame individually?


# Yes, absolutely. In both  SampleHandler.swift and  InAppCaptureViewModel.swift :

## 1. Every captured video frame (CVPixelBuffer) is converted into JPEG byte representation (jpegData).
## 2. The JPEG payload is immediately encrypted frame-by-frame using AES-256-GCM via Apple's CryptoKit

```
let sealedBox = try AES.GCM.seal(jpegData, using: key)
```

## 3. The encrypted payload (sealedBox.combined) is then dispatched to the streaming/network queue.


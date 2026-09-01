# Frame Integrity Ledger (Cryptographic Frame Integrity Ledger). The Frame Integrity Ledger is an on-device cryptographic audit dashboard.

## 1. During capture, an unencrypted, low-overhead thumbnail preview is generated in local RAM directly from the raw buffer before payload transmission.

## 2. This thumbnail is then attached to the local ledger record so that developers and users can visually verify which screen state corresponds to which SHA-256 hash and AES encryption tag in the ledger.

----------------------------------------------------------------------------
----------------------------------------------------------------------------

# Features :

## Pipeline 1) - SHA-256 over raw CVPixelBuffer bytes (original behavior)

Pixel Buffer Hashing: Updated InAppCaptureViewModel.swift to compute SHA-256 directly over raw CVPixelBuffer bytes instead of the compressed JPEGs, complying with Pipeline 1 specs.

Sequential Hash Chains: Maintained a sequence chain: 

Current Chain Hash = SHA256(Current Frame Hash + Previous Chain Hash)

Current Chain Hash = SHA256(Current Frame Hash + Previous Chain Hash)

Frame Ledger Table: Built a tabular listing inside InAppCaptureView.swift
 detailing: Frame Index, Preview image, Timestamp, Size, Abbreviated SHA-256 hash, Chain status, and Encryption lock status.
Frame Detail View: Created FrameDetailView.swift
 showing:
- Scaled frame preview and relative timestamps.
- Interactive cryptographic data flow diagram.
- Verification badges (Chain Status VALID and Encryption ENCRYPTED).
- Session metadata (Sequence, UUID).
- Collapsible Hex Preview showcasing the first 32 bytes of the encrypted JPEG payload.


## Pipeline 2) - JPEG-encode first, then SHA-256 over the compressed bytes 

(Details to be added iA in here ...)

----------------------------------------------------------------------------
----------------------------------------------------------------------------


# Individual Frame Encryption: 

## Every captured video frame's JPEG representation IS encrypted individually using AES-256-GCM with CryptoKit and hardware-bound keys (Secure Enclave / Keychain).

## Why Ledger Thumbnails Are Visible: To provide real-time diagnostic auditing without taxing memory, a lightweight preview thumbnail is generated in local RAM at capture time. In production streaming/storage workflows, the encrypted AES payload is transmitted or stored, requiring decryption via AES.GCM.open with the symmetric key before display.

----------------------------------------------------------------------------
----------------------------------------------------------------------------

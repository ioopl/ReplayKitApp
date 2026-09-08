# An important Architectural Question (we need to decide)

# The client's actual security requirement is integrity of each captured frame, not specifically "JPEG must be hashed." Before implementation, the architecture should explicitly establish whether the canonical frame is: 
# CVPixelBuffer bytes 
            or 
# JPEG bytes


see also [./docs/JPEG vs Frame.md] file
# (JPEG ≠ Video frame)
# One captured video frame can be converted into one complete JPEG image. The JPEG is represented internally as a sequence of bytes. It is not normally a chunk of an image.


# The client's specification says:
# "Compute SHA-256 over each frame in real time on-device"

# That does not necessarily mean you should JPEG-encode the frame first and hash the JPEG.

So there are two possible designs now: 

# Option A — Hash the Original frame

CMSampleBuffer
      ↓
CVPixelBuffer
      ↓
deterministic pixel bytes
      ↓
SHA-256
      ↓
Frame Hash

```
For example:

    Frame #1827
    SHA-256:
    8e91f4a7...

This is potentially the cleaner integrity architecture because you're hashing the captured frame representation directly.
```

# Option B — Hash the JPEG first

Original diagram appears to show:

CMSampleBuffer
      ↓
JPEG conversion
      ↓
JPEG Data
      ↓
SHA-256
      ↓
AES-GCM

```
For example:

The hash represents the JPEG representation of the frame, not necessarily the original pixel buffer. That is perfectly possible, but you should explicitly define this in the architecture. And this matters because:
same visual frame
      ↓
different JPEG encoder settings
      ↓
different JPEG bytes
      ↓
different SHA-256

So the client needs to decide what exactly constitutes the canonical "frame.
```


# Conceptually: That is much closer to what the Client Architecture is asking for:

CapturedFrame
      │
      ├── FramePayload
      │      └── JPEG Data
      │
      ├── FrameIntegrityRecord
      │      ├── SHA-256
      │      ├── Previous Hash
      │      └── Chain Hash
      │
      └── EncryptedFrame
             ├── Ciphertext
             ├── Nonce
             └── Authentication Tag
             
             

Ref: https://chatgpt.com/s/t_6a7c4779316c8191bb1f4621e105c177


#  Encryption Mechanics: What are we encrypting?

In Option B (In-App Raw Frame Capture), we convert each video frame to JPEG data and immediately encrypt it using CryptoKit AES-GCM using a 256-bit symmetric key created via the device's Secure Enclave.

## Why do we display this? 
In high-security enterprise apps (e.g., banking apps, HIPAA-compliant telehealth, secure messaging), the raw UI screen frames are sensitive. End-to-end encryption (E2EE) ensures that the captured stream is locked on-device using hardware keys, and can only be decrypted by authorized endpoints possessing the matching session key.

## For System-Wide Broadcast (Option C), 
The exact same encryption flow can be applied inside SampleHandler before pushing packets over WebRTC/RTMP. The symmetric session key is retrieved from the Shared Keychain to lock the stream payload directly on the GPU before transmitting it over public networks.

## Q: So I am confused, we are encrypting the frames or not, for both Option B and C, if we are encrypting is that before we convert it to a .MP4 file or afterwards ? I mean the .MP4 video output in both Option B and C is a .MP4 not some encrypted file which we somehow decrypt right? so how does it work? are we really encrypting and if so is that before we convert to .MP4 like frames by frames when its captured and just at the end we are decrypting and convertying that to .MP4 for output, or is the encryption is reserved when we would Live Stream or do Real Time Screen sharing etc! and thats where the encryption comes into use?

----------------------------------------------------------------------------
----------------------------------------------------------------------------

# AES-GCM encryption/decryption (for : Video and Frames)
AES-GCM is extremely fast on modern iPhones, especially for the small individual frame payloads we process.
The important distinction is:
- The Secure Enclave protects and identifies the key.
- Bulk AES-GCM encryption/decryption is performed by CryptoKit and the device’s optimized CPU/system cryptography—not by repeatedly sending every frame through the Secure Enclave.
- CryptoKit’s AES.GCM.open also verifies the authentication tag while decrypting. Apple CryptoKit documentation
Why it feels instant:
1. Individual frames are relatively small JPEG payloads.
2. Gallery thumbnails are even smaller.
3. Only the selected frame is decrypted when opening frame details.
4. Video decryption happens asynchronously.
5. The current recordings are probably short enough that decryption completes before the user notices.
6. The expensive parts are usually JPEG conversion, video decoding, disk I/O, and rendering—not AES itself.

----------------------------------------------------------------------------
----------------------------------------------------------------------------

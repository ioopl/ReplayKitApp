#  Encryption Mechanics: What are we encrypting?

In Option B (In-App Raw Frame Capture), we convert each video frame to JPEG data and immediately encrypt it using CryptoKit AES-GCM using a 256-bit symmetric key created via the device's Secure Enclave.

## Why do we display this? 
In high-security enterprise apps (e.g., banking apps, HIPAA-compliant telehealth, secure messaging), the raw UI screen frames are sensitive. End-to-end encryption (E2EE) ensures that the captured stream is locked on-device using hardware keys, and can only be decrypted by authorized endpoints possessing the matching session key.

## For System-Wide Broadcast (Option C), 
The exact same encryption flow can be applied inside SampleHandler before pushing packets over WebRTC/RTMP. The symmetric session key is retrieved from the Shared Keychain to lock the stream payload directly on the GPU before transmitting it over public networks.

## Q: So I am confused, we are encrypting the frames or not, for both Option B and C, if we are encrypting is that before we convert it to a .MP4 file or afterwards ? I mean the .MP4 video output in both Option B and C is a .MP4 not some encrypted file which we somehow decrypt right? so how does it work? are we really encrypting and if so is that before we convert to .MP4 like frames by frames when its captured and just at the end we are decrypting and convertying that to .MP4 for output, or is the encryption is reserved when we would Live Stream or do Real Time Screen sharing etc! and thats where the encryption comes into use?

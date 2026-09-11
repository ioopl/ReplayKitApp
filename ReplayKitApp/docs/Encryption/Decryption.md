#  Decryption Mechanics: How does decryption work in production??

## In a live production stream (e.g. streaming to a remote client over WebRTC or playing back an encrypted recording):

## - The network payload consists ONLY of the encrypted AES-256-GCM bytes (sealedBox).

## - The receiver fetches the matching symmetric key from the shared Secure Enclave / Keychain and performs decryption on demand:
```
let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
let image = UIImage(data: decryptedData)
```
----------------------------------------------------------------------------
----------------------------------------------------------------------------

# In-App MP4 Recording
The encrypted MP4 is decrypted into a temporary playback file before AVPlayer starts, so a 500 MB recording will take noticeably longer than a 10 MB recording.
For larger recordings, the user may eventually see a delay. 
----------------------------------------------------------------------------
----------------------------------------------------------------------------

## - The raw image payload is never transmitted unencrypted over the network.

----------------------------------------------------------------------------
----------------------------------------------------------------------------

# 1. Key Distribution & JWT in Production

## Q: Where does the symmetric key come from for Decryption in a production environment?
In a production end-to-end encrypted (E2EE) video streaming architecture (such as enterprise screen sharing or HIPAA-compliant WebRTC stream):

## 1. Elliptic-Curve Diffie-Hellman (ECDH) Key Exchange:
The sender (capturing iOS device) and receiver (watching client or server node) each generate an ephemeral EC key pair (or use Secure Enclave hardware keys).
During session handshake over TLS, both parties exchange their Public Keys.
Using ECDH, both sides compute the exact same 256-bit shared SymmetricKey in memory without ever sending the secret symmetric key over the wire.

## 2. Symmetric Key Wrapping (Alternative):
The capturing client generates a random 256-bit AES key.
It encrypts ("wraps") this AES key using the authorized recipient's Public Key (SecKeyCreateEncrypted).
The recipient decrypts ("unwraps") the AES key using their Private Key in their Secure Enclave/Keyring.

----------------------------------------------------------------------------

## Q: Could a JWT token be used to encrypt? How is it shared?

The Role of JWT: A JWT (JSON Web Token) is used for Authentication & Authorization (e.g., proving the user is logged in and authorized to join a streaming channel). It is not used directly as an AES encryption key because JWTs are signed tokens containing metadata, not 256-bit symmetric key bytes.

Combined Flow in Production:

Auth Phase: Client presents JWT token to Signaling Server  --→ Server validates token & admits client to session.

Handshake Phase: Sender & Receiver exchange public keys over the authenticated TLS channel via ECDH.

Streaming Phase: Client encrypts JPEG/H.264 frame chunks with AES.GCM.seal(data, using: symmetricKey) and streams the payload.

Decryption Phase: Receiver decrypts chunks with AES.GCM.open(sealedBox, using: symmetricKey) and renders frames in real time.

----------------------------------------------------------------------------

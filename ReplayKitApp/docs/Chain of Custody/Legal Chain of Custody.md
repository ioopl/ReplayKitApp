# Legal Chain of Custody

## What this feature means

The Legal Chain of Custody card is an inspection and audit-UX component. It
is not itself Secure Enclave, App Attest, or a legal certification service.
It presents cryptographic evidence produced by the capture pipeline so a
person can inspect the relationship between captured frames, their hashes,
and the device key identity used by the app.

The card is shared by `PostSessionSummaryView` and `FrameDetailView` through
`LegalChainOfCustodyCard`.

## How the layers relate

These are related layers, but they answer different questions:[See image attached](Chain Layers.png)

| Layer | What it answers | Current status |
| --- | --- | --- |
| Frame hash chain | Were the recorded frame bytes changed after the chain was created? | Implemented locally |
| Secure Enclave key | Is the private key protected by device hardware, and which public-key identity is associated with it? | Implemented with simulator/software fallback |
| Legal Chain of Custody card | Can a user inspect and copy the local evidence and understand its status? | Implemented as UI |
| Apple App Attest | Can a backend establish that requests came from a legitimate instance of this app? | Planned, not implemented |
| X.509 verification | Can the backend validate the certificate trust path in App Attest attestation data? | Planned, not implemented |

The card combines local evidence from the first two layers. It does not turn that evidence into Apple App Attest verification. App Attest is documented in [Apple DeviceCheck - App Attest](App Attest/App Attest-Apple DeviceCheck.md)

## Current frame and thumbnail storage

The current ledger is primarily an in-memory inspection view; it is not an
encrypted image gallery.

### In-App Capture

- Each processed frame is converted to JPEG and encrypted with AES-GCM during
  `InAppCaptureViewModel.processAndEncryptFrame`.
- The encrypted payload is also persisted by `EncryptedFrameStore` as an
  authenticated file in the shared App Group container.
- A sealed thumbnail is stored beside the sealed frame payload. The UI only
  decrypts it into a `UIImage` when it needs to render a preview.
- The in-app records array is capped at the most recent 20 records and is
  cleared when a new capture starts.
- The separately finalized MP4 is written to a temporary URL by the video
  writer and is not the same thing as the per-frame AES-GCM payload.

### System-wide Broadcast

- The Broadcast Upload Extension creates and AES-GCM-encrypts the JPEG frame
  for the streaming pipeline and persists the same frame through
  `EncryptedFrameStore`.
- Every tenth frame still writes a small live ledger entry to App Group
  `UserDefaults`, but that entry now contains metadata only; thumbnail bytes
  are not stored there.
- The host app decrypts thumbnails when loading the live ledger. The complete
  session gallery reads the encrypted-frame manifest from the App Group store.
- The system-wide MP4 output is written separately by the broadcast writer;
  its current file path and the per-frame sealed payload are separate storage
  paths.

### What tapping a frame does

When the user taps a row in `FrameIntegrityLedgerView`, the app selects the
existing in-memory `FrameRecord` and presents `FrameDetailView`. The
session-summary gallery behaves differently: it authenticates the sealed
AES-GCM payload and thumbnail, recomputes the chain hash, and only then opens
the verified image in `FrameDetailView`.

The live ledger remains a lightweight preview. The session summary is the
encrypted-frame gallery.

## Persistence, sandboxing, and app restart behavior

`EncryptedFrameStore` writes to the App Group container returned by
`containerURL(forSecurityApplicationGroupIdentifier:)`. This is still
sandboxed storage: only the signed host app and its configured extension can
access it. It is not publicly accessible like Photos or a web server.

The frame payload and thumbnail files are encrypted with AES-GCM and written
with iOS file-protection options. The symmetric key remains in the shared
Keychain. This gives defense in depth: App Group sandboxing controls which
processes can reach the files, while AES-GCM protects the bytes if the files
are copied without the key.

The encrypted files normally survive:

- capture completion;
- force-quit and app relaunch;
- device restart;
- app updates, provided the App Group identifier and Keychain configuration
  remain unchanged.

They are removed when the user deletes the local buffer, and they should not
be treated as uninstall-proof archival storage. Uninstalling the app, changing
the App Group, losing the encryption key, or a deliberate retention/cleanup
policy can make the files unavailable.

### Current restart behavior

SwiftData now provides the durable session catalog, and the app scans surviving
`EncryptedFrames/<sessionID>` directories at launch to import sessions that are
missing from that catalog. The Session Summary displays the resulting catalog
status and encrypted frame count. A full user-facing “Saved Sessions” history
screen and richer missing-key/corruption recovery actions remain follow-up UI
work; recovered data is not silently presented as verified when its manifest or
key cannot be used.

## Encrypted frame gallery

The session-summary gallery uses this storage contract:

1. During capture, write each sealed JPEG payload to an app-private or App
   Group file using a session/frame identifier. Store the AES-GCM combined
   representation (nonce, ciphertext, and authentication tag), not plaintext
   JPEG bytes.
2. Store a manifest containing frame index, hash values, chain values,
   timestamp, resolution, payload path, and session ID. The manifest is still a
   small JSON index; authenticating/encrypting the manifest itself remains a
   hardening TODO and must be completed before treating the manifest alone as
   tamper-evident evidence.
3. Store gallery thumbnails as separately sealed AES-GCM payloads. A thumbnail
   can be decrypted only when the gallery/detail screen needs to render it;
   the resulting `UIImage` should remain in memory only.
4. `PostSessionSummaryView` presents `EncryptedFrameGalleryView` using the
   session ID and manifest-backed gallery model.
5. On tap, read the sealed file, decrypt with the shared session key, verify
   the authentication tag, recompute the frame hash, and compare it with the
   manifest before showing the image.
6. Delete the session directory and manifest together when the user deletes
   the local buffer. Use an explicit retention policy rather than leaving
   orphaned frame files.

File storage is preferable to putting image bytes in `UserDefaults`: it avoids
large plist values, supports streaming and cleanup, and makes per-frame
authenticated encryption practical. `UserDefaults` should contain only small
indexes or status values, not gallery image data.

The proposed gallery would still decrypt a preview briefly in memory in order
to display it. “Encrypted gallery” means encrypted at rest and authenticated
before display; it does not mean pixels remain encrypted while rendered on
screen.

## What the current app produces

### Frame hash chain

For each captured frame, the app computes a frame hash and links it to the
previous chain value:

```text
frameHash       = SHA-256(frame bytes or selected pixel representation)
chainHash[n]    = SHA-256(frameHash[n] + chainHash[n-1])
```

The app stores/displays the frame hash, previous chain hash, current chain
hash, and session identifier in `FrameRecord`. This makes later changes to a
frame or to the ordering of the chain detectable if the original evidence is
available for comparison.

### Secure Enclave public-key fingerprint

`SharedKeychainManager.publicKeyFingerprint()` locates the persisted EC key,
obtains its public half, exports only the public representation, and computes
its SHA-256 digest. The UI formats the digest as a short value such as
`0x8F4A...B621`.

The private key is not exported. On a supported physical device the key is
created with `kSecAttrTokenIDSecureEnclave`; simulator and unavailable-
entitlement paths use a software fallback. A software fallback must never be
described to an end user as hardware proof.

### Timestamp limitation

The current frame timestamp is an elapsed capture-session value such as
`00:03.214`. It is useful for ordering frames, but it is not currently a
trusted wall-clock timestamp and is not signed by a timestamp authority. The
card should therefore describe it as a capture-relative timestamp until the
app stores an absolute UTC time and binds it into a signed/exported evidence
record.

### Chain-signature limitation

The current “Chain Hash signature” value is a SHA-256 chain hash, not a
digital signature. A hash detects changes when compared with an authentic
original, but it does not prove who created the original. A future evidence
package should add a real signature over a canonical manifest, using an
appropriate signing key and, for remote trust, a server verification record.

## What an end user can prove today

Today, an end user can inspect local, reproducible evidence—not complete legal
custody:

1. Open the frame detail or post-session summary card.
2. View the displayed frame hash, previous hash, chain hash, timestamp, session
   ID, and public-key fingerprint. The current `FrameDetailView` provides a
   `Copy Hash` action for the frame hash only; the remaining values are
   currently view-only and must be transcribed or captured until the copy/export
   TODOs below are implemented.
3. Preserve the original encrypted capture, frame metadata, and the displayed
   values together.
4. Recompute the frame and chain hashes independently using the documented
   canonical inputs.
5. Compare the recomputed final chain hash and public-key fingerprint with the
   values shown by the app.
6. Record whether the device used Secure Enclave hardware or the software
   fallback, and retain the app version, OS version, and capture settings.

This can show that the preserved local evidence is internally consistent. It
cannot, by itself, prove that the app was genuine, that the device clock was
correct, that the user did not control the capture process, or that the
evidence has legal standing in a particular jurisdiction. Legal admissibility
depends on the surrounding process, independent verification, retention, and
the applicable jurisdiction; this document is not legal advice.

## What is needed for a stronger proof package

The following should be implemented before calling the result a complete
chain-of-custody record:

- A canonical, versioned evidence manifest containing session identity,
  absolute UTC timestamps, frame count, selected hash pipeline, every chain
  input, final chain hash, key fingerprint, app version, OS version, and
  capture configuration.
- A deterministic export format for the manifest and the encrypted capture.
- A digital signature over the canonical manifest. The verifier must know
  which key created the signature and how that key is trusted.
- A verification tool or backend endpoint that recomputes the chain and
  returns a durable verification report.
- Immutable or append-only storage with access logs, retention policy, and a
  documented handoff process.
- If remote app/device trust is required, Apple App Attest registration and
  assertion verification on a backend, including certificate-chain and
  counter validation.
- An explicit record of failures, unsupported devices, fallback mode, and
  any manual intervention.

## UI TODO checklist

### Correctness and status

- [ ] Rename the current green “Hardware-Enclave Attestation — Verified” label
  to “Secure Enclave Key Integrity” until real App Attest verification exists.
- [ ] Show separate statuses for `Secure Enclave`, `Software fallback`,
  `App Attest server verified`, `Pending`, `Unavailable`, and `Failed`.
- [ ] Do not show “Zero Alteration Guarantee” as an absolute claim. Use wording
  such as “Hash chain currently consistent with captured metadata” after actual
  recomputation.
- [ ] Recompute and validate the chain before displaying a green valid state;
  do not rely only on a stored `isChainValid` flag.
- [ ] Distinguish “chain hash” from “digital signature” in all labels.

### Explainability

- [ ] Add an information button or sheet explaining the four layers in the
  table above using plain language.
- [ ] Add “What this proves” and “What this does not prove” text directly in
  the card or its detail sheet.
- [ ] Explain that the timestamp is capture-relative until absolute UTC
  timestamping is implemented.
- [ ] Display whether the key is hardware-backed or software fallback.
- [ ] Show the exact hash algorithm and canonical input version.

### User verification and export

- [ ] Add copy buttons for the complete, untruncated hashes and fingerprint.
- [ ] Add “Export Evidence Package” containing the encrypted capture,
  canonical manifest, metadata, verification results, and a README.
- [ ] Add “Verify Evidence Package” locally or through a trusted verifier and
  show exactly which checks passed or failed.
- [ ] Include an evidence package ID, creation time, app version, OS version,
  and schema version.
- [ ] Warn users not to rely on a screenshot of the card as proof.

### App Attest integration

- [ ] Replace the local placeholder badge with a server-controlled App Attest
  result once the backend roadmap is implemented.
- [ ] Show verification request ID, server verification time, App Attest key
  identifier/fingerprint, and assertion counter.
- [ ] Link the verified server result to the exact final chain hash and
  evidence package ID.
- [ ] Provide clear recovery/fallback behavior when App Attest is unsupported,
  offline, or rejected.

## Recommended implementation order

1. Correct the current UI wording and implement real local chain
   recomputation.
2. Add canonical manifest generation and complete-hash copy/export.
3. Add local evidence-package verification.
4. Add digital signing and a trusted verification report.
5. Implement the App Attest backend and client registration/assertion flow.
6. Bind the server verification result to the final chain hash and update the
   UI to show separate local-integrity and server-attestation statuses.

The first step improves honesty and usability without requiring a backend. A
backend becomes necessary when the product needs a remote party to trust the
capture as an authentic app/device event rather than merely inspect locally
consistent evidence.

## Durable persistence implementation

The app now has two complementary stores:

1. SwiftData is the searchable catalog. `RecordingDocumentEntity` is the
   recording/document row (the conceptual `tblDocs` table), and `FrameEntity`
   is its child ledger row (the conceptual `tblFrames` table). Each frame has a
   relationship to its parent document and the document owns the frames with a
   cascade delete rule.
2. The App Group directory is the encrypted evidence store. AES-GCM frame
   payloads, thumbnails, and the encrypted video remain files because large
   binary media should not be placed inside database rows. SwiftData stores
   their metadata and filenames, not the image/video bytes.

The local `userID` is a generated app identity. It must not be confused with
the Secure Enclave public-key fingerprint: a fingerprint identifies the
cryptographic key/device context, while a user ID identifies the local account
(or, later, a server account). If a backend is added, the server account ID
should replace or supplement the local ID; the key fingerprint remains a
separate evidence field.

At app launch, `PersistenceRecoveryView` scans the encrypted App Group session
directories and imports any session not already present in SwiftData. This is
why a force-quit, relaunch, or device restart no longer loses the app's ability
to rediscover saved frame evidence. The Session Summary also shows a small
Persistence card with the catalog status, encrypted frame count, and validation
message.

The five recovery concerns are:

1. Durable session catalog: SwiftData keeps the document/session list on disk.
2. Session recovery at launch: the app scans surviving encrypted session
   folders and rebuilds missing catalog rows.
3. Manifest/key validation: the app checks that metadata is present and that
   the key is available before treating evidence as usable; missing keys or
   corrupt authenticated files must be shown as a recovery failure, never as a
   green verification.
4. Saved Sessions UI: the history screen queries `RecordingDocumentEntity` and
   opens recovered sessions rather than relying on the last in-memory capture.
5. Recovery states: the UI should distinguish saved/verified, saving,
   missing-key, corrupted-file, unsupported-device, and deleted states.

## Encrypted MP4 playback

The frame gallery and the MP4 are different artifacts. `AVAssetWriter` creates
an ordinary MP4 stream, so encrypting the individual JPEG evidence frames does
not automatically encrypt the separately generated MP4. The app now encrypts
the completed MP4 in authenticated AES-GCM chunks, writes
`recording.mp4.enc`, applies file protection, and removes the plaintext writer
output. The MP4 is therefore encrypted at rest in the App Group container.

When the user taps Play, the app decrypts the chunks into a protected temporary
playback file, gives that URL to `AVPlayer`, and deletes the temporary plaintext
file when the player disappears. This is necessary because `AVPlayer` cannot
play a custom AES-GCM file format directly. A future hardened implementation
could use a custom byte-range resource loader, but it would still need to
decrypt media bytes for the decoder; the current temporary-file flow is simpler
and easier to audit.

Saving a copy to Photos is intentionally separate: Photos is user-controlled
exported storage and may contain a plaintext playable copy. The app's private
local recording remains encrypted at rest, but “saved to Photos” should not be
described as encrypted private storage.

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

These are related layers, but they answer different questions: (See image attached)

| Layer | What it answers | Current status |
| --- | --- | --- |
| Frame hash chain | Were the recorded frame bytes changed after the chain was created? | Implemented locally |
| Secure Enclave key | Is the private key protected by device hardware, and which public-key identity is associated with it? | Implemented with simulator/software fallback |
| Legal Chain of Custody card | Can a user inspect and copy the local evidence and understand its status? | Implemented as UI |
| Apple App Attest | Can a backend establish that requests came from a legitimate instance of this app? | Planned, not implemented |
| X.509 verification | Can the backend validate the certificate trust path in App Attest attestation data? | Planned, not implemented |

The card combines local evidence from the first two layers. It does not turn
that evidence into Apple App Attest verification. App Attest is documented in
[Apple DeviceCheck - App Attest](App%20Attest%20-%20Apple%20DeviceCheck.md).

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

Today, an end user can demonstrate local, reproducible evidence—not complete
legal custody:

1. Open the frame detail or post-session summary card.
2. Copy the displayed frame hash, previous hash, chain hash, timestamp, session
   ID, and public-key fingerprint.
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

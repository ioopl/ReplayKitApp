# Apple DeviceCheck - App Attest

## Resources

WWDC26: Secure your apps with App Attest | Apple
https://www.youtube.com/watch?v=Njzk0TdaJbw

Protect Your Backend From Fake IOS Clients — App Attest Step-By-Step Tutorial
https://www.youtube.com/watch?v=_EgdZuwLqug

Validating apps that connect to your server
https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server

## Purpose

This document records how the app protects captured frames and how the UI's
chain-of-custody inspection is intended to be understood. The app currently
uses a Secure Enclave-backed EC key (with a software fallback for simulator
and unsupported environments), a shared Keychain/App Group session key, and a
SHA-256 frame hash chain.

The inspection card displays:

- The SHA-256 fingerprint of the exported public representation of the
  persisted signing key. Only public key bytes are exported; the private key
  is never exported.
- The frame's cryptographic timestamp.
- The frame's chain hash, which links the current frame hash to the previous
  frame hash.

## DeviceCheck and App Attest are different from the local key fingerprint

`DeviceCheck` and `App Attest` are Apple services for establishing device/app
integrity with a server. A local Secure Enclave key fingerprint proves which
public key the app is currently using; by itself it does not prove to a remote
server that the app binary is genuine or that a device has not been modified.

For a production legal or remote-verification workflow, the backend should
also verify an App Attest attestation and assertion. The backend, not the
client UI, must decide whether a session is trusted.

## Current implementation

1. `SharedKeychainManager.generateSecureEnclaveKey()` creates a P-256 EC key
   pair with `kSecAttrTokenIDSecureEnclave` and a private-key access-control
   policy. On simulator or when Secure Enclave entitlements are unavailable,
   it creates a software EC key pair so tests and development remain usable.
2. `publicKeyFingerprint()` finds the persisted key by its application tag,
   obtains its public key, exports the public representation, and computes
   `SHA-256(publicKeyBytes)`. The UI formats the digest as `0xABCD...1234`.
3. Each frame is hashed and linked to the previous chain value. The resulting
   chain hash is shown in `FrameDetailView` and summarized in
   `PostSessionSummaryView`.
4. Frame payloads are encrypted with AES-GCM using the shared symmetric key.

## Important status: what is and is not implemented (ToDo:)

The current app does **not** yet call `DCAppAttestService`, send an App Attest
attestation to a server, verify an App Attest assertion, or perform X.509
certificate-chain verification. The current UI is a local Secure Enclave key
and frame-ledger inspection tool.

The phrase “Hardware-Enclave Attestation — Verified” should therefore be
treated as a UI placeholder for the local key-integrity signal until the
server-backed work below is complete. It must not be presented as Apple App
Attest verification yet.

## Do we need a backend server?

For real App Attest security, **yes**. A server is required because the client
cannot securely verify its own claim that it is legitimate. The server must
issue unpredictable challenges, receive the attestation/assertion, validate
Apple's signatures and certificate chain, track assertion counters, and make
the trust decision.

We can demonstrate the client API without a backend by generating a key on a
physical device and displaying local status, but that does not provide
meaningful protection against a modified client or replay across a network.
The backend does not need to be a traditional always-on server: a small API,
serverless function, or managed service is sufficient, provided it can keep
secrets and durable per-device state. The App Attest private key stays on the
device; the server stores the registered key identifier, public key, and
assertion counter.

## Target architecture

```text
App                         Backend                         Apple
 |                             |                              |
 |-- request one-time challenge ->|                          |
 |<-- challenge ------------------|                          |
 | generate/keep App Attest key  |                          |
 |-- attestation + key ID ------>|-- validate X.509 chain -->|
 |                               |<-- Apple trust result ----|
 |<-- registration accepted -----|                          |
 |                               |                          |
 |-- session challenge ---------->|                          |
 |<-- challenge ------------------|                          |
 |-- assertion + chain metadata ->| verify signature/counter |
 |<-- server verification result -|                          |
```

X.509 validation is one part of the backend's App Attest attestation
verification. DeviceCheck is the Apple service family; App Attest is the
`DCAppAttestService` feature within it; X.509 is a certificate format and
trust-validation mechanism used while checking the attestation data.

## Implementation TODO and plan

### Phase 0 — Product and Apple setup

- [ ] Decide the backend deployment: a small HTTPS service, serverless
  functions, or an existing API.
- [ ] Register and confirm the production App ID, bundle identifier, and Team
  ID in the Apple Developer account.
- [ ] Confirm App Attest support and define development/production
  environments. App Attest is not available on every device type.
- [ ] Decide the policy for unsupported devices, Apple service outages, and
  development builds: allow reduced-security mode, block capture, or allow
  local-only capture with a visible warning.
- [ ] Define what “verified session” means for the product and legal/audit
  requirements. The client UI must not make a stronger claim than the server
  result supports.

### Phase 1 — Backend challenge and registration API

- [ ] Add an authenticated endpoint that returns a random, single-use,
  short-lived challenge for App Attest registration.
- [ ] Add a registration endpoint that accepts the App Attest key ID and
  attestation object over HTTPS.
- [ ] Store the registered key ID, extracted public key, environment, app
  identity, creation time, and registration status.
- [ ] Make challenge storage one-time-use and bind it to the intended user,
  installation, and operation.
- [ ] Never put the App Attest private key or server signing secrets in the
  app bundle.

### Phase 2 — Client `DCAppAttestService` integration

- [ ] Add an `AppAttestService` wrapper around
  `DCAppAttestService.shared`.
- [ ] Check `isSupported` before using the service.
- [ ] Generate an App Attest key once and persist only its key identifier in
  the Keychain. The private key is managed by Apple's service and remains on
  the device.
- [ ] Request a backend challenge, hash the canonical challenge bytes, and
  call `attestKey(_:clientDataHash:)`.
- [ ] Send the resulting attestation object and key ID to the backend.
- [ ] Cache the server's registration result, but allow the backend to require
  re-registration when policy or key state requires it.
- [ ] Keep this App Attest key separate from the existing frame-encryption
  key and the existing local Secure Enclave fingerprint key.

### Phase 3 — Backend attestation and X.509 verification

- [ ] Decode the App Attest attestation object using a vetted CBOR/WebAuthn
  implementation rather than handwritten parsing where possible.
- [ ] Verify the attestation statement's signature and certificate chain to
  Apple's trusted App Attest root/intermediate certificates.
- [ ] Validate the app identity, Team ID/App ID, environment, challenge,
  key identifier, and nonce/client-data hash.
- [ ] Extract and store the App Attest public key only after every validation
  succeeds.
- [ ] Reject expired, malformed, unknown-root, wrong-app, wrong-environment,
  reused-challenge, and otherwise invalid attestations.
- [ ] Pin and version the trusted Apple certificate material through a
  controlled server-side update process; do not ship a server trust decision
  in the client.

### Phase 4 — Assertion verification for capture sessions

- [ ] Add a backend endpoint that issues a fresh challenge for starting or
  finalizing a capture session.
- [ ] Define one canonical byte encoding for the challenge plus session ID,
  session metadata, and final frame-chain hash.
- [ ] Hash those canonical bytes on the client and call
  `generateAssertion(_:clientDataHash:)` with the registered key ID.
- [ ] Send the assertion, key ID, challenge ID, session ID, chain hash, and
  relevant capture metadata to the backend.
- [ ] Verify the assertion signature with the registered App Attest public
  key, validate the app identity and challenge, and require a strictly
  increasing assertion counter.
- [ ] Atomically update the stored counter so concurrent or replayed requests
  cannot both succeed.
- [ ] Store the server verification result with the session audit record.

### Phase 5 — UI and audit behavior

- [ ] Change the current local badge to “Secure Enclave Key Integrity” until
  a server verification result is available.
- [ ] Add a distinct “Apple App Attest — Server Verified” state that is driven
  only by a signed/authenticated backend response.
- [ ] Show the verification time, verification/request ID, App Attest key ID
  fingerprint, assertion counter, and the exact chain hash that was verified.
- [ ] Show “Unsupported”, “Pending”, “Failed”, and “Reduced security” states;
  do not silently convert a failed attestation into a green verified badge.
- [ ] Keep the local frame hash-chain display useful even when App Attest is
  unavailable, while clearly labelling it as local evidence.

### Phase 6 — Testing and operations

- [ ] Unit-test canonical challenge encoding, hash inputs, fingerprint
  formatting, and chain-hash reproduction.
- [ ] Use captured Apple test fixtures to test valid and invalid attestation
  and assertion objects on the backend.
- [ ] Test wrong app ID, wrong Team ID, wrong environment, altered payload,
  reused challenge, stale counter, concurrent requests, and certificate-chain
  failures.
- [ ] Test supported physical devices, unsupported devices, simulator, fresh
  install, reinstall, backup/restore, offline mode, and App Attest service
  errors.
- [ ] Monitor verification failures without logging private keys, raw
  sensitive payloads, or unnecessary attestation contents.
- [ ] Document key rotation, certificate trust updates, data retention, and
  incident response before calling the result legal-grade evidence.

## Recommended first milestone

The safest first implementation milestone is a small backend with two
endpoints: `POST /app-attest/challenge` and `POST /app-attest/register`. Add
the client wrapper and registration flow first, verify the attestation on the
server, and only then connect assertion verification to capture-session
finalization. This keeps the existing local ledger feature working while the
stronger remote trust path is introduced incrementally.

## Condensed App Attest flow

When a server is introduced, the recommended flow is:

1. The app asks `DCAppAttestService` to generate an App Attest key and sends
   the attestation object plus a server-provided, single-use challenge to the
   backend.
2. The backend validates the attestation chain, app identifier, key
   identifier, challenge, and environment before registering the key.
3. For each important session, the backend sends a fresh challenge. The app
   hashes the challenge and session claims, creates an assertion with the App
   Attest key, and sends the assertion with the claims and chain metadata.
4. The backend verifies the assertion counter is strictly increasing, checks
   the challenge and app identity, and stores the verified chain hash and
   public-key fingerprint with the session record.

Do not use a client-generated timestamp, client-side “verified” label, or
client-provided fingerprint as the sole proof of integrity. They are useful
for inspection and audit UX; server verification is required for trust across
an untrusted network.

## Best practices and limitations

- Never export, log, or persist the Secure Enclave private key.
- Use `ThisDeviceOnly` accessibility for device-bound private-key material and
  avoid weakening access control just to make a flow easier to test.
- Treat simulator/software fallback results as development evidence, not as
  hardware attestation.
- Use replay-resistant, server-issued challenges for App Attest assertions.
- Persist and validate the App Attest assertion counter on the server.
- Keep the App Attest key separate from the frame-encryption key. App Attest
  authenticates the app/device relationship; AES-GCM protects frame contents.
- Define a documented fallback policy for unsupported devices and service
  outages. Reduced-security mode should be an explicit backend decision.
- Preserve the exact chain inputs and canonical encoding used to calculate
  hashes so an auditor can independently reproduce a session signature.

## Testing

Unit tests can validate hash-chain construction, fingerprint formatting, and
Keychain fallback behavior without requiring App Attest. Real Secure Enclave
and App Attest validation must be tested on physical, supported devices with
the production signing configuration and a backend verifier.

## Apple references

- [DCAppAttestService](https://developer.apple.com/documentation/devicecheck/dcappattestservice)
- [Establishing your app's integrity](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity)
- [Validating apps that connect to your server](https://developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server)

# App Attest & Fallback Service code structure
# App Attest in Local & Simulator Environments


Q: Well I have iPhones so this is not an issue right?

A: Yes, having a physical iPhone makes testing the live App Attest flow fully possible!


However, we still need to write the software fallback logic for two important reasons:

1. Jailbreak/Root Fallback: In production, if a legitimate user’s device hardware fails the App Attest handshake (e.g., due  to custom MDM profiles or unsupported legacy iOS versions), the backend needs a fallback verification path to decidewhether to allow the stream in "reduced security mode" or block it entirely.

2. Automated Unit Tests: Our test suite runs on simulators. Without the software fallback, the unit tests would fail to compile or execute because the App Attest APIs would throw immediate errors.

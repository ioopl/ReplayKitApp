#  What is the difference between an AES-256 and SHA-256 ? Why they have 256 in common?

## AES-256 is a two-way encryption algorithm that scrambles data into a secret code using a key so it can be unmasked later. 

## SHA-256 is a one-way cryptographic hash function that turns any data into a fixed 256-bit signature to prove it was not changed. 

## They share "256" because both use 256 bits of data length, but AES-256 uses it for a secret key size, while SHA-256 uses it for the output size.


# 🛑 Core Differences

# AES-256 (Advanced Encryption Standard)
## Purpose: Keeps data hidden and secret.
## Direction: Two-way (reversible). You encrypt data with a key, and decrypt it with the same key.
## Input/Output: Input data size matches output data size.

# SHA-256 (Secure Hash Algorithm)
## Purpose: Checks data safety and truth (integrity).
## Direction: One-way (irreversible). You cannot turn the output back into the original data.
## Input/Output: Any input size (a short word or a massive file) always shrinks down to a fixed 256-bit (32-byte) output.

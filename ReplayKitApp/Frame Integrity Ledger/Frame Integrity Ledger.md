# Frame Integrity Ledger (Cryptographic Frame Integrity Ledger).

Features :

 


Pipeline 1) SHA-256 over raw CVPixelBuffer bytes (original behavior)

Pixel Buffer Hashing: Updated InAppCaptureViewModel.swift to compute SHA-256 directly over raw CVPixelBuffer bytes instead of the compressed JPEGs, complying with Pipeline 1 specs.

Sequential Hash Chains: Maintained a sequence chain: 

Current Chain Hash = SHA256(Current Frame Hash + Previous Chain Hash)

Current Chain Hash=SHA256(Current Frame Hash+Previous Chain Hash)

Frame Ledger Table: Built a tabular listing inside InAppCaptureView.swift
 detailing: Frame Index, Preview image, Timestamp, Size, Abbreviated SHA-256 hash, Chain status, and Encryption lock status.
Frame Detail View: Created FrameDetailView.swift
 showing:
- Scaled frame preview and relative timestamps.
- Interactive cryptographic data flow diagram.
- Verification badges (Chain Status VALID and Encryption ENCRYPTED).
- Session metadata (Sequence, UUID).
- Collapsible Hex Preview showcasing the first 32 bytes of the encrypted JPEG payload.

----------------------------------------------------------------------------

Pipeline 2) 
JPEG-encode first, then SHA-256 over the compressed bytes 

(Details to be added in Sha Allah in here ...)

#  Decryption Mechanics: How does decryption work in production??

In a live production stream (e.g. streaming to a remote client over WebRTC or playing back an encrypted recording):

## - The network payload consists ONLY of the encrypted AES-256-GCM bytes (sealedBox).

## - The receiver fetches the matching symmetric key from the shared Secure Enclave / Keychain and performs decryption on demand:
```
let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
let image = UIImage(data: decryptedData)
```

## - The raw image payload is never transmitted unencrypted over the network.



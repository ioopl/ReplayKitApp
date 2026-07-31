import ReplayKit
import CryptoKit
@testable import ReplayKitApp

class MockKeychainService: KeychainServiceProtocol {
    var keyPairGenerated = false
    var symmetricKey: SymmetricKey?
    var shouldFail = false
    
    func generateSecureEnclaveKey() throws {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1)
        }
        keyPairGenerated = true
    }
    
    func getOrCreateSymmetricKey() throws -> SymmetricKey {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1)
        }
        let key = SymmetricKey(size: .bits256)
        self.symmetricKey = key
        return key
    }
    
    func getSymmetricKey() throws -> SymmetricKey? {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1)
        }
        return symmetricKey
    }
    
    func deleteSymmetricKey() throws {
        if shouldFail {
            throw NSError(domain: "MockError", code: -1)
        }
        symmetricKey = nil
    }
}

import XCTest
import Combine
import ReplayKit
import CryptoKit
@testable import ReplayKitApp

// MARK: - Tests

final class ReplayKitAppTests: XCTestCase {
    
    @MainActor
    func testInAppRecordingViewModelState() async {
        let mockService = MockScreenRecorderService()
        let viewModel = InAppRecordingViewModel(recorderService: mockService)
        
        XCTAssertFalse(viewModel.isRecording)
        
        viewModel.startRecording()
        try? await Task.sleep(nanoseconds: 100_000_000) // allow task to execute
        XCTAssertTrue(viewModel.isRecording)
        
        viewModel.stopRecording()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(viewModel.isRecording)
    }
    
    @MainActor
    func testInAppCaptureViewModelState() async {
        let mockService = MockScreenRecorderService()
        let mockKeychain = MockKeychainService()
        let viewModel = InAppCaptureViewModel(recorderService: mockService, keychainService: mockKeychain)
        
        XCTAssertFalse(viewModel.isCapturing)
        
        viewModel.startCapture()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(viewModel.isCapturing)
        XCTAssertNotNil(try? mockKeychain.getSymmetricKey())
        
        viewModel.stopCapture()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(viewModel.isCapturing)
    }
    
    @MainActor
    func testSystemWideScreenBroadcastViewModelState() async {
        let mockKeychain = MockKeychainService()
        let viewModel = SystemWideScreenBroadcastViewModel(keychainService: mockKeychain)
        
        XCTAssertFalse(viewModel.isAuthenticated)
        
        viewModel.authenticateAndPrepareKeys()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertTrue(viewModel.isAuthenticated)
        XCTAssertTrue(mockKeychain.keyPairGenerated)
        XCTAssertNotNil(try? mockKeychain.getSymmetricKey())
    }
    
    @MainActor
    func testInAppClipsViewModelState() async {
        let mockService = MockScreenRecorderService()
        let viewModel = InAppClipsViewModel(recorderService: mockService)
        
        XCTAssertFalse(viewModel.isClipBuffering)
        
        viewModel.startClipBuffering()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(viewModel.isClipBuffering)
        
        viewModel.exportClip()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(viewModel.isExporting)
        XCTAssertEqual(viewModel.lastExportedClipURL?.path, "/tmp/mock_clip.mp4")
        
        viewModel.stopClipBuffering()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(viewModel.isClipBuffering)
    }
    
    func testSharedKeychainManagerProductionSaveRetrieve() {
        let manager = SharedKeychainManager.shared
        
        // Clean up previous runs
        try? manager.deleteSymmetricKey()
        
        do {
            let initialKey = try manager.getSymmetricKey()
            XCTAssertNil(initialKey)
            
            let createdKey = try manager.getOrCreateSymmetricKey()
            let retrievedKey = try manager.getSymmetricKey()
            
            XCTAssertNotNil(retrievedKey)
            
            // Compare bytes of the two symmetric keys
            let createdData = createdKey.withUnsafeBytes { Data($0) }
            let retrievedData = retrievedKey!.withUnsafeBytes { Data($0) }
            XCTAssertEqual(createdData, retrievedData)
            
            try manager.deleteSymmetricKey()
            XCTAssertNil(try manager.getSymmetricKey())
        } catch {
            XCTFail("Keychain operation failed: \(error)")
        }
    }
}

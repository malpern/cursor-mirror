import XCTest
@testable import CursorWindowCore

final class HLSStreamManagerTests: XCTestCase {
    var manager: HLSStreamManager!
    
    override func setUp() async throws {
        manager = HLSStreamManager()
    }
    
    override func tearDown() async throws {
        manager = nil
    }
    
    func testRequestAccess() async throws {
        // Test successful access request
        let streamKey = try await manager.requestAccess()
        XCTAssertNotNil(streamKey)
        
        // Test stream in use
        do {
            _ = try await manager.requestAccess()
            XCTFail("Should throw streamInUse error")
        } catch {
            XCTAssertTrue(error is HLSStreamManager.HLSStreamError)
        }
    }
    
    func testValidateAccess() async throws {
        // Test with invalid key
        let invalidKey = UUID()
        let isValidInvalid = await manager.validateAccess(invalidKey)
        XCTAssertFalse(isValidInvalid, "Invalid key should not be valid")
        
        // Test with valid key
        let streamKey = try await manager.requestAccess()
        let isValidValid = await manager.validateAccess(streamKey)
        XCTAssertTrue(isValidValid, "Valid key should be valid")
    }
    
    func testReleaseAccess() async throws {
        // Get access first
        let streamKey = try await manager.requestAccess()
        
        // Release access
        await manager.releaseAccess(streamKey)
        
        // Should be able to get new access
        let newStreamKey = try await manager.requestAccess()
        XCTAssertNotEqual(streamKey, newStreamKey)
    }
    
    func testConnectionTimeout() async throws {
        // Get access
        let streamKey = try await manager.requestAccess()
        let isValid = await manager.validateAccess(streamKey)
        XCTAssertTrue(isValid, "Stream key should be valid initially")
        
        // Simulate timeout check
        await manager.checkTimeout()
        
        // Should still be valid since not enough time has passed
        let isStillValid = await manager.validateAccess(streamKey)
        XCTAssertTrue(isStillValid, "Stream key should still be valid before timeout")
    }
} 
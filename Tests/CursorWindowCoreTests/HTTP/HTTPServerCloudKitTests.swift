import XCTest
@testable import CursorWindowCore

@MainActor
final class HTTPServerCloudKitTests: XCTestCase {
    var serverManager: HTTPServerManager!
    var mockDeviceService: MockDeviceRegistrationService!
    
    override func setUp() async throws {
        try await super.setUp()
        mockDeviceService = MockDeviceRegistrationService()
        serverManager = await HTTPServerManager()
    }
    
    override func tearDown() async throws {
        try await serverManager.stop()
        serverManager = nil
        mockDeviceService = nil
        try await super.tearDown()
    }
    
    func testServerStartSuccessWithCloudKit() async throws {
        // Given
        mockDeviceService.shouldSucceed = true
        
        // When
        try await serverManager.start()
        
        // Then
        XCTAssertTrue(serverManager.isRunning)
        XCTAssertTrue(mockDeviceService.registerCalled)
        XCTAssertEqual(mockDeviceService.registerCallCount, 1)
    }
    
    func testServerStartSuccessWithCloudKitFailure() async throws {
        // Given
        mockDeviceService.shouldSucceed = false
        
        // When
        try await serverManager.start()
        
        // Then
        XCTAssertTrue(serverManager.isRunning) // Server should still start even if CloudKit fails
        XCTAssertTrue(mockDeviceService.registerCalled)
        XCTAssertEqual(mockDeviceService.registerCallCount, 1)
    }
    
    func testServerStopSuccess() async throws {
        // Given
        mockDeviceService.shouldSucceed = true
        try await serverManager.start()
        XCTAssertTrue(serverManager.isRunning)
        
        // When
        try await serverManager.stop()
        
        // Then
        XCTAssertFalse(serverManager.isRunning)
        XCTAssertTrue(mockDeviceService.markOfflineCalled)
    }
    
    func testServerStopWithCloudKitFailure() async throws {
        // Given
        mockDeviceService.shouldSucceed = true
        try await serverManager.start()
        XCTAssertTrue(serverManager.isRunning)
        mockDeviceService.shouldSucceed = false
        
        // When
        try await serverManager.stop()
        
        // Then
        XCTAssertFalse(serverManager.isRunning)
        XCTAssertTrue(mockDeviceService.markOfflineCalled)
    }
    
    func testMultipleStartCallsOnlyRegisterOnce() async throws {
        // Given
        mockDeviceService.shouldSucceed = true
        
        // When
        try await serverManager.start()
        try await serverManager.start()
        
        // Then
        XCTAssertTrue(serverManager.isRunning)
        XCTAssertEqual(mockDeviceService.registerCallCount, 1) // Should only register once
    }
    
    func testServerRestartRegistersAgain() async throws {
        // Given
        mockDeviceService.shouldSucceed = true
        try await serverManager.start()
        XCTAssertTrue(serverManager.isRunning)
        
        // When
        try await serverManager.stop()
        XCTAssertFalse(serverManager.isRunning)
        try await serverManager.start()
        
        // Then
        XCTAssertTrue(serverManager.isRunning)
        XCTAssertEqual(mockDeviceService.registerCallCount, 2) // Should register again after restart
    }
}

// Mock device registration service for testing
class MockDeviceRegistrationService: DeviceRegistrationServiceProtocol {
    var shouldSucceed = true
    var registerCalled = false
    var markOfflineCalled = false
    var registerCallCount = 0
    var markOfflineCallCount = 0
    
    func registerDevice(serverIP: String) async throws -> Bool {
        registerCalled = true
        registerCallCount += 1
        if shouldSucceed {
            return true
        }
        throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock registration failure"])
    }
    
    static func markOffline(deviceID: String?) async throws -> Bool {
        return true
    }
    
    func markOffline() async throws -> Bool {
        markOfflineCalled = true
        markOfflineCallCount += 1
        if shouldSucceed {
            return true
        }
        throw NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock mark offline failure"])
    }
} 
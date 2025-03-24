//
//  StreamConfigTests.swift
//  CursorMirrorClient
//
//  Created by Micah Alpern on 3/23/25.
//

import XCTest
@testable import CursorMirrorClient

final class StreamConfigTests: XCTestCase {
    var sut: StreamConfig!
    let testDefaults = UserDefaults.standard
    
    override func setUp() {
        super.setUp()
        // Clean user defaults before each test
        testDefaults.removeObject(forKey: "streamQuality")
        testDefaults.removeObject(forKey: "bufferSize")
        testDefaults.synchronize()
        
        sut = StreamConfig(userDefaults: testDefaults)
    }
    
    override func tearDown() {
        // Clean UserDefaults
        testDefaults.removeObject(forKey: "streamQuality")
        testDefaults.removeObject(forKey: "bufferSize")
        
        // Force a synchronize to make sure defaults are flushed
        testDefaults.synchronize()
        
        // Clear object references
        sut = nil
        
        // Run a short runloop spin to allow any pending operations to complete
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // Use our termination helper
        terminateTestProcesses()
        
        super.tearDown()
    }
    
    func testDefaultConfiguration() {
        XCTAssertEqual(sut.quality, .auto)
        XCTAssertEqual(sut.bufferSize, 3.0)
        XCTAssertTrue(sut.isAutoQualityEnabled)
    }
    
    func testQualitySelection() {
        // Test manual quality selection
        sut.quality = .high
        XCTAssertEqual(sut.quality, .high)
        XCTAssertFalse(sut.isAutoQualityEnabled)
        
        // Test auto quality selection
        sut.quality = .auto
        XCTAssertEqual(sut.quality, .auto)
        XCTAssertTrue(sut.isAutoQualityEnabled)
    }
    
    func testBufferSizeValidation() {
        // Test valid buffer size
        sut.bufferSize = 5.0
        XCTAssertEqual(sut.bufferSize, 5.0)
        
        // Test minimum buffer size
        sut.bufferSize = 0.5
        XCTAssertEqual(sut.bufferSize, StreamConfig.minimumBufferSize)
        
        // Test maximum buffer size
        sut.bufferSize = 15.0
        XCTAssertEqual(sut.bufferSize, StreamConfig.maximumBufferSize)
    }
    
    func testStreamURLGeneration() {
        // Arrange
        let deviceID = "test-device"
        let baseURL = "http://localhost:8080"
        
        // Act
        let streamURL = sut.generateStreamURL(forDevice: deviceID, baseURL: baseURL)
        
        // Assert
        XCTAssertNotNil(streamURL)
        XCTAssertTrue(streamURL.absoluteString.contains(deviceID))
        XCTAssertTrue(streamURL.absoluteString.contains(baseURL))
        XCTAssertTrue(streamURL.absoluteString.contains("quality=\(sut.quality.rawValue)"))
    }
    
    func testQualityAdjustment() {
        // Test quality increase
        sut.quality = .medium
        sut.adjustQualityBasedOnBandwidth(available: 10_000_000) // 10 Mbps
        XCTAssertEqual(sut.quality, .high)
        
        // Test quality decrease
        sut.adjustQualityBasedOnBandwidth(available: 1_000_000) // 1 Mbps
        XCTAssertEqual(sut.quality, .low)
    }
    
    func testConfigurationPersistence() {
        // Arrange - create dedicated UserDefaults for this test
        let testSuiteName = "ConfigPersistenceTest"
        let persistenceDefaults = UserDefaults(suiteName: testSuiteName)!
        
        // Clear any existing values
        persistenceDefaults.removeObject(forKey: "streamQuality")
        persistenceDefaults.removeObject(forKey: "bufferSize")
        persistenceDefaults.synchronize()
        
        // Create first config that will save values
        let configToSave = StreamConfig(skipDefaultsClear: true, userDefaults: persistenceDefaults)
        configToSave.quality = .high
        configToSave.bufferSize = 5.0
        configToSave.saveConfiguration()
        
        // Wait briefly to ensure values are saved
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        
        // Create a new config that should load the saved values
        let loadedConfig = StreamConfig(skipDefaultsClear: true, userDefaults: persistenceDefaults)
        
        // Assert
        XCTAssertEqual(loadedConfig.quality, .high)
        XCTAssertEqual(loadedConfig.bufferSize, 5.0)
        
        // Cleanup
        persistenceDefaults.removeSuite(named: testSuiteName)
    }
    
    func testResetToDefaults() {
        // Arrange
        sut.quality = .high
        sut.bufferSize = 5.0
        
        // Act
        sut.resetToDefaults()
        
        // Assert
        XCTAssertEqual(sut.quality, .auto)
        XCTAssertEqual(sut.bufferSize, 3.0)
        XCTAssertTrue(sut.isAutoQualityEnabled)
    }
}


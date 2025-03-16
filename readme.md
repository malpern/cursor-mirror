# CursorWindow

A macOS application for capturing and streaming screen content with HLS (HTTP Live Streaming) support.

## Project Status

### Phase 1: Viewport UI (✅ Completed)
- Draggable viewport with iPhone 15 Pro dimensions (393x852 pixels)
- Blue border with glow effect for visibility
- Large hit area for easy dragging (60px inside and outside)
- Stays on top but allows interaction with windows underneath
- Works across all spaces and full-screen apps
- Proper app switching support (Cmd+Tab)
- Quit via menu bar or Cmd+Q

### Phase 2: Screen Capture & Streaming (✅ Completed)
- [✅] Screen capture of viewport region using ScreenCaptureKit
  - ✅ Basic permission handling implemented
  - ✅ Test infrastructure set up
  - ✅ Frame capture implementation completed
  - ✅ Integration tests completed and passing
- [✅] Real-time H.264 video encoding with AVFoundation/VideoToolbox
  - ✅ H.264 encoder implementation with proper thread safety
  - ✅ Frame processing pipeline with pixel buffer copying
  - ✅ Video file writing with proper error handling
  - ✅ Comprehensive test coverage
  - ✅ Memory-safe frame processing
- [✅] HLS stream generation with segmented .ts files
  - ✅ TSSegmentWriter implementation
  - ✅ M3U8 playlist generation
  - ✅ HLS manager for coordinating streaming
  - ✅ Async/await support for thread safety
- [ ] Local HTTP server for stream distribution
- [ ] iOS client app for stream playback

## Features

- Screen capture with customizable viewport
- Draggable viewport with keyboard shortcuts and menu controls
- HLS streaming with adaptive bitrate support
- Real-time H.264 video encoding
- Configurable encoding settings (frame rate, bitrate)
- Preview mode for capture area
- Tab-based interface for preview and encoding controls

## Recent Improvements

### BasicFrameProcessor Enhancements (✅ Complete)
- [x] Frame rate monitoring
  - Added frame count tracking
  - Implemented average processing time calculation
  - Added real-time FPS monitoring
  - Added dropped frame detection
- [x] Thread-safe state management
  - Implemented actor-based state updates
  - Added safe statistics and configuration access
  - Thread-safe callback handling
- [x] Basic frame transformations
  - Added support for CIFilters
  - Implemented pixel buffer copying
  - Added proper buffer locking/unlocking
- [x] Metadata handling
  - Added timing information extraction
  - Added format description capture
  - Added attachment preservation
- [x] Comprehensive test coverage
  - Added configuration tests
  - Added statistics tracking tests
  - Added dropped frame detection tests
  - Added thread safety tests

### Code Stabilization (✅ Complete)
- [x] Reorganized project into proper Swift package structure
  - Core functionality in `CursorWindowCore` module
  - App-specific code in `CursorWindow` module
- [x] Improved concurrency handling
  - Added proper actor isolation for frame processing
  - Implemented thread-safe screen capture management
  - Fixed Swift 6 concurrency warnings
  - Separated protocol conformance for better type safety
- [x] Enhanced permission handling
  - Streamlined screen capture permission flow
  - Added proper error handling and user feedback
- [x] Refactored view models
  - Proper dependency injection using environment
  - Clear separation of concerns
  - Thread-safe state management
- [x] Fixed all build issues and warnings
  - Resolved circular dependencies
  - Proper module imports
  - Clean build with no warnings
  - Proper macOS 14.0 availability annotations

### H264VideoEncoder Improvements (✅ Complete)
- [x] Thread-safe frame processing
  - Proper pixel buffer copying for thread safety
  - Serial queue for maintaining frame order
  - Actor-based state management
- [x] Improved error handling
  - Comprehensive error checks and logging
  - Proper cleanup on errors
  - Clear error messages for debugging
- [x] Memory management
  - Proper buffer locking/unlocking
  - Weak references to prevent retain cycles
  - Automatic cleanup of resources
- [x] Video configuration
  - Optimized H.264 baseline profile settings
  - Real-time encoding support
  - Configurable frame rate and bitrate

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/cursor-window.git
cd cursor-window
```

2. Build and run using Xcode or Swift Package Manager:
```bash
swift build
```

## Usage

1. Launch the application
2. Grant screen recording permission when prompted
3. Use the Preview tab to position the capture viewport:
   - Drag the viewport to desired position
   - Use Cmd + Arrow keys for precise positioning
   - Use View > Reset Position to center the viewport
4. Switch to the Encoding tab to configure and start streaming:
   - Adjust frame rate and bitrate as needed
   - Click "Start Encoding" to begin streaming
   - Access HLS stream at the configured URL

## Development

### Project Structure

- `Sources/CursorWindow/`: Main application code
- `Sources/CursorWindowCore/`: Core functionality
  - `HLS/`: HLS streaming implementation
  - `Capture/`: Screen capture components
  - `Encoding/`: Video encoding components
- `Tests/`: Unit and UI tests

### Testing Strategy

#### Unit Tests
- Test individual components in isolation
- Mock dependencies using protocols
- Focus on edge cases and error conditions

#### Integration Tests
- Test component interactions
- Verify proper setup and teardown
- Ensure correct permission handling

#### Performance Tests
- Measure frame capture rates
- Monitor memory usage
- Track CPU utilization

### Test Categories

#### Permission Tests (✅ Implemented)
```swift
class ScreenCaptureManagerTests: XCTestCase {
    func testInitialPermissionStatus()
    func testPermissionRequest()
    func testHandlePermissionGranted()
}
```

#### Display Tests (✅ Complete)
```swift
class DisplayConfigurationTests: XCTestCase {
    func testEnumerateDisplays()
    func testGetMainDisplay()
    func testDisplayBounds()
}
```

#### Region Tests (✅ Complete)
```swift
class CaptureRegionTests: XCTestCase {
    func testRegionBounds()
    func testRegionUpdate()
    func testRegionValidation()
    func testCreateFilter()
}
```

#### Frame Tests (✅ Complete)
```swift
class FrameCaptureTests: XCTestCase {
    func testInitialState()
    func testFrameRateChange()
    func testStartCapture()
    func testStopCapture()
    func testUpdateContentFilter()
    func testSetFrameProcessor()
}
```

#### Error Handling Tests (✅ Implemented)
```swift
class ErrorHandlingTests: XCTestCase {
    func testCaptureErrorDescriptions()
    func testFrameProcessorErrorHandling()
    func testFrameCaptureManagerErrorHandling()
}
```

#### Encoding Tests (✅ Implemented)
```swift
class VideoEncoderTests: XCTestCase {
    func testInitialState()
    func testStartSession()
    func testEncodeFrame()
    func testEncodeMultipleFrames()
    func testEndSession()
}

class EncodingFrameProcessorTests: XCTestCase {
    func testInitialState()
    func testStartEncoding()
    func testProcessFrame()
    func testStopEncoding()
    func testHandleError()
}

class VideoFileWriterTests: XCTestCase {
    func testCreateFile()
    func testAppendEncodedData()
    func testAppendMultipleFrames()
    func testFinishWriting()
    func testCancelWriting()
}
```

#### HLS Tests (✅ Implemented)
```swift
class HLSManagerTests: XCTestCase {
    func testStartStreaming()
    func testStopStreaming()
    func testProcessEncodedData()
    func testSegmentRotation()
    func testCleanupOldSegments()
}

class TSSegmentWriterTests: XCTestCase {
    func testStartNewSegment()
    func testWriteEncodedData()
    func testFinishCurrentSegment()
    func testMultipleSegments()
}

class PlaylistGeneratorTests: XCTestCase {
    func testGeneratePlaylist()
    func testUpdateSegments()
    func testCleanupOldSegments()
}
```

### UI Tests (✅ Complete)
- [x] DraggableViewport UI Tests
  - Initial state verification
  - Dragging behavior
  - Screen boundary constraints
  - Keyboard shortcuts
  - Menu bar interactions
- [x] MainView UI Tests
  - Tab view functionality
  - Encoding controls
  - Settings adjustments
  - Permission handling
  - Preview controls

## Development Process

1. For each feature:
   - Write failing test
   - Implement minimal code to pass
   - Refactor while keeping tests green
   - Document changes

2. Before merging:
   - All tests must pass
   - No memory leaks
   - Performance metrics met

## Performance Optimizations

- **Background Processing**: Frame processing occurs on a dedicated background queue
- **Throttled Updates**: UI updates are limited to 60fps maximum to maintain responsiveness
- **Metal Rendering**: Using Metal-accelerated rendering for captured frames display
- **Debounced Controls**: UI controls use debouncing to prevent excessive processing
- **Task Management**: Proper cancellation of ongoing tasks when starting new operations

## License

[Your license information here]

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

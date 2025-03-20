# Cursor Mirror

A macOS application that captures and streams a portion of your screen matching the iPhone 15 Pro dimensions. Perfect for screen recordings, presentations, or development workflows where you need to mirror content to iOS devices.

## Project Status

### Phase 1: Viewport UI (✅ Completed)
- Draggable viewport with iPhone 15 Pro dimensions (393x852 pixels)
- Blue border with glow effect for visibility
- Large hit area for easy dragging (60px inside and outside)
- Stays on top but allows interaction with windows underneath
- Works across all spaces and full-screen apps
- Proper app switching support (Cmd+Tab)
- Quit via menu bar or Cmd+Q

### Phase 2: Screen Capture & Streaming (🚧 In Progress)
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
- [🚧] HTTP server for stream distribution
  - ✅ Basic server implementation
  - ✅ Authentication management implementation
  - ✅ Request logging middleware
  - ✅ Admin dashboard controller
  - ✅ HTTP server error handling
  - 🚧 Integration with video processing pipeline
  - 🚧 Stream endpoint implementation
- [ ] HLS stream generation with segmented .ts files
- [ ] iOS client app for stream playback

## Recent Improvements

### HTTP Server Implementation (🚧 In Progress)
- [x] Core HTTP server architecture
  - Server configuration with customizable settings
  - Authentication middleware with session management
  - Logging middleware for request/response tracking
  - Error handling with descriptive status codes
- [x] Swift 6 compatibility improvements
  - Fixed actor isolation warnings
  - Properly implemented async/await patterns
  - Ensured Sendable conformance where needed
- [ ] Stream delivery endpoints
  - HLS manifest generation
  - Video segment serving
  - Real-time stream initiation

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
  - Memory-safe frame management
  - Robust error handling and validation
  - Comprehensive test coverage
- HLS streaming implementation
  - MPEG-TS segment generation with proper timing
  - M3U8 playlist management (Master, Media, Event, VOD)
  - Efficient segment rotation and cleanup
  - Variant stream support
  - Async/await support for thread safety
  - Improved segment timing accuracy
- Local HTTP server for stream distribution
  - Phase 1: Core Server Implementation
    - Vapor-based HTTP server with configuration options
    - Basic routing (health check, version endpoint)
    - Static file serving capability
    - Comprehensive server tests
  - Phase 2: HLS Integration
    - HLS endpoint routes
    - Single-connection stream access control
    - Connection timeout handling
    - Master and media playlist generation
    - Video segment handling and delivery
  - Phase 3: Advanced Features
    - Authentication (multiple methods, protected routes, session management)
    - CORS support (configurable settings, preflight requests)
    - Request logging (with configurable levels and filtering)
    - Rate limiting (with configuration options and IP-based tracking)
    - Admin dashboard (UI for configuration, monitoring, and management)

🚧 **In Progress**
  - Phase 4: Performance & Security
    - [ ] Optimize segment delivery
    - [ ] Add SSL/TLS support
    - [ ] Write performance tests
    - [ ] Implement security best practices
    - [ ] Add monitoring and metrics
  - Phase 5: UI Integration
    - [ ] Add server controls to main UI
    - [ ] Create QR code for mobile connection
    - [ ] Add server status indicators
    - [ ] Implement connection management
    - [ ] Add error handling and user feedback
- iOS client app for stream playback

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Quick Start

1. Clone and build:
```bash
git clone https://github.com/yourusername/cursor-window.git
cd cursor-window
swift build
```

2. Launch and use:
   - Grant screen recording permission when prompted
   - Use Preview tab to position capture viewport
   - Use Encoding tab to configure and start streaming
   - Access HLS stream at the configured URL

## Project Structure

```
Sources/
├── CursorWindowCore/           # Core functionality module
│   ├── SharedTypes.swift       # Shared protocols and types
│   ├── ScreenCaptureManager.swift
│   ├── BasicFrameProcessor.swift
│   ├── H264VideoEncoder.swift  # Thread-safe video encoding
│   └── HTTP/                   # HTTP server components
│       ├── HTTPServerManager.swift
│       ├── AuthenticationManager.swift
│       ├── RequestLog.swift
│       ├── ServerConfig.swift
│       └── Middleware/
│           ├── LoggingMiddleware.swift
│           └── AuthMiddleware.swift
└── CursorWindow/              # Main app module
    ├── CursorWindowApp.swift
    ├── AppDelegate.swift
    └── Views/
        ├── MainView.swift
        └── DraggableViewport.swift
```

## Development

### Testing
- Comprehensive test suite with 70+ tests across all components:
  - HLS streaming and segment management
  - H.264 video encoding
  - Frame processing
  - Screen capture
  - HTTP server and HLS integration
  - Admin dashboard functionality
  - Authentication and security
  - Run tests: `swift test`

### Feature Highlights

#### HLS Features
- Configurable segment duration and playlist length
- Automatic segment rotation and cleanup
- Support for multiple variant streams
- Event and VOD playlist generation
- Base URL configuration for flexible deployment

#### HTTP Server Features
- Authentication (Basic, Token, API Key)
- CORS support with configurable policies
- Request logging with filtering and levels
- Rate limiting with multiple strategies
- Admin dashboard for monitoring and management

#### Admin Dashboard Features
- Dashboard overview with real-time monitoring
- Stream management interface
- Settings configuration panel
- Log viewer with filtering and export
- Authentication protection
- Responsive design with Bootstrap 5

## Next Steps

### Phase 4: Performance & Security
The next phase focuses on optimizing performance and enhancing security:
- Segment delivery optimization to reduce latency
- SSL/TLS support for secure connections
- Performance benchmarking and optimization
- Security hardening with best practices
- Monitoring and metrics integration

### Phase 5: UI Integration
The final phase will integrate the HTTP server with the main application UI:
- Server controls in the main application interface
- QR code generation for easy mobile connection
- Server status indicators in the UI
- Connection management interface
- Improved error handling and user feedback

## Known Issues and Limitations

1. UI Tests temporarily disabled due to Swift 6 compatibility issues with XCUITest
2. HTTP server implementation not yet integrated with video processing pipeline
3. HLS stream generation not yet implemented
4. iOS client app not yet available

## Coming Soon
1. Local network streaming via HLS
2. iOS client app for viewing the stream
3. Fixed UI tests with full Swift 6 compatibility

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - See LICENSE file for details

## Testing Strategy

### Unit Tests
- Test individual components in isolation
- Mock dependencies using protocols
- Focus on edge cases and error conditions

### Integration Tests
- Test component interactions
- Verify proper setup and teardown
- Ensure correct permission handling

### Performance Tests
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
```

```swift
class EncodingFrameProcessorTests: XCTestCase {
    func testInitialState()
    func testStartEncoding()
    func testProcessFrame()
    func testStopEncoding()
    func testHandleError()
}
```

```swift
class VideoFileWriterTests: XCTestCase {
    func testCreateFile()
    func testAppendEncodedData()
    func testAppendMultipleFrames()
    func testFinishWriting()
    func testCancelWriting()
}
```

### HTTP Server Tests (🚧 In Progress)
```swift
class HTTPServerManagerTests: XCTestCase {
    func testServerConfiguration()
    func testStartServer()
    func testStopServer()
    func testRequestLogging()
    func testAuthenticationFlow()
}
```

### UI Tests (❌ Temporarily Disabled)
- [ ] DraggableViewport UI Tests
  - Initial state verification
  - Dragging behavior
  - Screen boundary constraints
  - Keyboard shortcuts
  - Menu bar interactions
- [ ] MainView UI Tests
  - Tab view functionality
  - Encoding controls
  - Settings adjustments
  - Permission handling
  - Preview controls

## Development Roadmap

### 1. Project Setup (✅ Complete)
- [x] 1.1. Create macOS Xcode project
- [x] 1.2. Configure project settings

### 2. Screen Capture (✅ Complete)
#### 2.1 Screen Capture Setup & Permissions (✅ Complete)
- [x] 2.1.1. Add ScreenCaptureKit framework
- [x] 2.1.2. Create ScreenCaptureManager class skeleton
- [x] 2.1.3. Implement permission request handling
- [x] 2.1.4. Write tests for permission states
- [x] 2.1.5. Test permission request UI flow

#### 2.2 Display Configuration (✅ Complete)
- [x] 2.2.1. Create DisplayConfiguration model
- [x] 2.2.2. Implement display enumeration
- [x] 2.2.3. Write tests for display detection
- [x] 2.2.4. Add display selection logic
- [x] 2.2.5. Test display bounds calculations

#### 2.3 Capture Region (✅ Complete)
- [x] 2.3.1. Create CaptureRegion model
- [x] 2.3.2. Implement viewport region tracking
- [x] 2.3.3. Write tests for region calculations
- [x] 2.3.4. Add region update handling
- [x] 2.3.5. Test region bounds validation

#### 2.4 Frame Capture Pipeline (✅ Complete)
- [x] 2.4.1. Create FrameProcessor protocol
- [x] 2.4.2. Implement basic frame capture
- [x] 2.4.3. Write tests for frame capture
- [x] 2.4.4. Add frame rate control
- [x] 2.4.5. Test frame delivery performance

#### 2.5 Integration (✅ Complete)
- [x] 2.5.1. Connect capture manager to viewport
- [x] 2.5.2. Implement capture preview
- [x] 2.5.3. Write integration tests
- [x] 2.5.4. Add error handling
  - [x] Custom `CaptureError` enum with user-friendly descriptions
  - [x] Improved permission handling using `SCShareableContent.current`
  - [x] Proper error propagation through the capture pipeline
- [x] 2.5.5. Test end-to-end capture flow

### 3. Video Encoding (✅ Complete)
- [x] 3.1. Setup AVFoundation/VideoToolbox pipeline
  - [x] Create `VideoEncoder` protocol and H.264 implementation
  - [x] Implement pixel format conversion
  - [x] Add configuration options for bitrate and profile
- [x] 3.2. Implement H.264 encoding
  - [x] Create `EncodingFrameProcessor` to handle frame encoding
  - [x] Implement video file writing with `VideoFileWriter`
  - [x] Add UI controls for encoding settings
- [x] 3.3. Test encoding performance
  - [x] Unit tests for encoder components
  - [x] Integration tests for the encoding pipeline
  - [x] Performance testing with various frame rates

### 4. HTTP Server (🚧 In Progress)
- [x] 4.1. Setup HTTP server foundation
  - [x] Implement HTTPServerManager
  - [x] Create ServerConfig with customizable options
  - [x] Add error handling with HTTPServerError
- [x] 4.2. Implement authentication
  - [x] Create AuthenticationManager
  - [x] Implement session management
  - [x] Add authentication middleware
- [x] 4.3. Add request logging
  - [x] Implement RequestLog model
  - [x] Create LoggingMiddleware
  - [x] Add admin dashboard for logs viewing
- [ ] 4.4. Implement HLS streaming
  - [ ] Create HLS segment generator
  - [ ] Add M3U8 playlist generation
  - [ ] Implement stream endpoint

### 5. HLS Implementation (📅 Planned)
- [ ] 5.1. Implement video segmentation
- [ ] 5.2. Generate M3U8 playlists
- [ ] 5.3. Test segment generation

### 6. Integration & Testing (🚧 In Progress)
- [x] 6.1. Core functionality testing
- [ ] 6.2. Performance optimization
- [x] 6.3. Swift 6 compatibility improvements
- [ ] 6.4. Fix UI tests
- [ ] 6.5. iOS client testing

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

- **Background Processing**: Frame processing now occurs on a dedicated background queue
- **Throttled Updates**: UI updates are limited to 60fps maximum to maintain responsiveness
- **Metal Rendering**: Using Metal-accelerated rendering for captured frames display
- **Debounced Controls**: UI controls use debouncing to prevent excessive processing
- **Task Management**: Proper cancellation of ongoing tasks when starting new operations
- **Async/Await**: Modern concurrency patterns for improved performance and safety

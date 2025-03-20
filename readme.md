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

### Phase 2: Screen Capture & Streaming (✅ Completed)
- Screen capture of viewport region using ScreenCaptureKit
- Real-time H.264 video encoding with AVFoundation/VideoToolbox
- HTTP server for stream distribution
  - Basic server implementation
  - Authentication management implementation
  - Request logging middleware
  - Admin dashboard controller
  - HTTP server error handling
  - Integration with video processing pipeline
  - Stream endpoint implementation
- HLS stream generation with segmented .ts files
  - Playlist generation (master and media playlists)
  - Video segment management
  - Multiple quality support
  - Integration with H.264 encoder
- iOS client app for stream playback

### Phase 3: Enhanced Functionality (⏱️ In Progress)
- Touch emulation controls
- Multiple viewport support
- Custom styling/theming
- Shortcut keys and hotkeys

## Recent Improvements

- Added Swift 6 compatibility with proper `Sendable` conformance across the codebase
- Improved actor isolation safety for thread-sensitive components
- Enhanced authentication system with better error handling and route protection
- Fixed unnecessary imports and module references in HTTP components
- Cleaned up unused code in HLS segment management
- Improved error handling in video segment generation and management
- Implemented better shutdown protocols for asynchronous operations
- Streamlined module structure to avoid circular dependencies
- Integrated HTTP server with authentication and improved middleware
- Added HLS streaming support with adaptive bitrate and multiple quality options

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 6.0.3 or later

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
2. Some test suites dependent on XCTVapor module require fixes
3. Performance optimizations needed for low-latency streaming

## Coming Soon
1. Performance optimizations for HLS segment delivery
2. iOS client app for viewing the stream
3. Fixed UI tests with full Swift 6 compatibility
4. Integration of real-time metrics dashboard

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

### 4. HTTP Server (✅ Complete)
- [x] 4.1. Setup HTTP server foundation
  - [x] Implement HTTPServerManager
  - [x] Create ServerConfig with customizable options
  - [x] Add error handling with HTTPServerError
- [x] 4.2. Implement authentication
  - [x] Create AuthenticationManager
  - [x] Implement session management
  - [x] Add authentication middleware
  - [x] Implement protected routes functionality
- [x] 4.3. Add request logging
  - [x] Implement RequestLog model
  - [x] Create LoggingMiddleware
  - [x] Add admin dashboard for logs viewing
- [x] 4.4. Implement HLS streaming
  - [x] Create HLS segment generator
  - [x] Add M3U8 playlist generation
  - [x] Implement stream endpoint

### 5. HLS Implementation (✅ Complete)
- [x] 5.1. Implement video segmentation
  - [x] Create HLSSegmentManager for MPEG-TS segment creation
  - [x] Add segment rotation and cleanup
  - [x] Implement multiple quality support
- [x] 5.2. Generate M3U8 playlists
  - [x] Create HLSPlaylistGenerator for master and variant playlists
  - [x] Implement playlist updating with new segments
  - [x] Add support for different playlist types (VOD/Live)
- [x] 5.3. Test segment generation
  - [x] Verify segment duration and content
  - [x] Test segment delivery and rotation
  - [x] Validate playlist generation

### 6. Integration & Testing (🚧 In Progress)
- [x] 6.1. Core functionality testing
- [x] 6.2. Swift 6 compatibility improvements
  - [x] Add proper actor isolation and Sendable conformance
  - [x] Fix unsafe async code patterns
  - [x] Update thread-safety mechanisms
- [ ] 6.3. Performance optimization
  - [ ] Optimize segment generation for lower latency
  - [ ] Improve memory management during encoding
  - [ ] Enhance error recovery mechanisms
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

## Architecture

The application is structured into several main components:

- **CursorWindow**: Main macOS application providing the UI
- **CursorWindowCore**: Core functionality module containing:
  - **WindowManager**: Handles window creation and management
  - **ViewportManager**: Manages the capture viewport
  - **ScreenCapture**: Screen capture implementation
  - **VideoEncoding**: H.264 encoder implementation
  - **HTTP**: HTTP server and streaming implementation
    - **Server**: Basic HTTP server
    - **Authentication**: User authentication
    - **Admin**: Admin dashboard and controls
    - **HLS**: HLS streaming components
      - Playlist generation
      - Segment management
      - Stream control
- **CursorWindowTests**: Unit tests for core functionality
- **CursorWindowUITests**: UI tests for macOS application

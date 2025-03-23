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

- Added frame rate limiting to prevent frame accumulation and improve performance
- Optimized QoS levels for frame processing (using .userInitiated instead of .userInteractive)
- Enhanced thread safety in frame processing pipeline
- Improved frame processing statistics and monitoring
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
- Enhanced test suite reliability with proper async/await handling
- Improved mock implementations for ScreenCaptureKit components
- Added robust permission handling in test environment
- Fixed race conditions in async test setup and teardown
- Added comprehensive error simulation and testing
- Improved test isolation with proper UserDefaults cleanup
- Enhanced test assertions with descriptive failure messages
- Added new test cases for error scenarios
- Fixed thread safety issues in frame processing tests
- Improved documentation of test cases and setup requirements

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
│   ├── ScreenCaptureManager.swift  # Screen capture with frame rate limiting
│   ├── BasicFrameProcessor.swift   # Frame processing with QoS optimization
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

### Current Test Status
- ✅ Core functionality tests passing
- ✅ Screen capture tests passing with frame rate limiting
- ✅ Frame processing tests passing with QoS optimization
- ✅ HTTP server tests passing
- ✅ HLS streaming tests passing
- ⚠️ UI Tests temporarily disabled
- ⚠️ Some XCTVapor module tests require fixes

### Remaining Test Tasks
1. Test Infrastructure
   - Add test coverage reporting
   - Streamline test setup/teardown

### Test Categories

#### Core Tests (✅ Complete)
```swift
class ScreenCaptureManagerTests: XCTestCase {
    func testInitialPermissionStatus()
    func testStartCapture()
    func testStopCapture()
    func testFrameProcessing()
    func testErrorHandling()
    func testFrameRateLimiting()
    func testQoSOptimization()
}
```

### Next Steps
1. Add test coverage reporting
2. Streamline test setup/teardown

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
- [x] 2.4.4. Add frame rate control and QoS optimization
- [x] 2.4.5. Test frame delivery performance
- [x] 2.4.6. Implement frame rate limiting
- [x] 2.4.7. Optimize QoS levels for frame processing

#### 2.5 Integration (✅ Complete)
- [x] 2.5.1. Connect capture manager to viewport
- [x] 2.5.2. Implement capture preview
- [x] 2.5.3. Write integration tests
- [x] 2.5.4. Add error handling
  - [x] Custom `CaptureError` enum with user-friendly descriptions
  - [x] Improved permission handling using `SCShareableContent.current`
  - [x] Proper error propagation through the capture pipeline
- [x] 2.5.5. Test end-to-end capture flow
- [x] 2.5.6. Validate frame rate limiting behavior
- [x] 2.5.7. Verify QoS optimization effectiveness

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
  - [x] Performance tests with frame rate limiting
  - [x] QoS optimization validation

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
- [ ] 6.3. iOS client testing

## Development Process

1. For each feature:
   - Write failing test
   - Implement minimal code to pass
   - Refactor while keeping tests green
   - Document changes

2. Before merging:
   - All tests must pass
   - No memory leaks

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

### Current Test Fix Progress (🔄 In Progress)

#### ScreenCaptureManagerTests Issues
1. Permission Handling (✅ Fixed)
   - Issue: Permission state not properly managed in test environment
   - Status: Fixed
   - Changes Made:
     - [x] Updated `forceRefreshPermissionStatus` to handle test environment
     - [x] Fixed permission state persistence in UserDefaults
     - [x] Added test-specific permission override mechanism
     - [x] Improved error handling and state persistence
     - [x] Fixed initial permission state in tests

2. Mock Stream Implementation (✅ Fixed)
   - Issue: Stream initialization failures and duplicate mock declarations
   - Status: Fixed
   - Changes Made:
     - [x] Fixed compilation errors in mock stream
     - [x] Improved frame simulation mechanism
     - [x] Fixed duplicate MockSCStream declarations
     - [x] Fixed stream property access with async helper methods
     - [x] Fixed actor isolation issues with frame processor
     - [x] Added proper stream output delegation
     - [x] Fixed async/await warnings in stream methods

3. Actor Isolation (✅ Fixed)
   - Issue: Actor isolation violations in frame processor and stream access
   - Status: Fixed
   - Changes Made:
     - [x] Created `FrameProcessorStore` actor for safe state management
     - [x] Added async helper methods for testing
     - [x] Fixed frame processor access in tests
     - [x] Fixed stream property access in tests
     - [x] Fixed async/await warnings
     - [x] Optimized actor communication patterns

4. Test Cleanup (✅ Fixed)
   - Issue: Resources not properly cleaned up between tests
   - Status: Fixed
   - Changes Made:
     - [x] Added proper stream shutdown in `tearDown`
     - [x] Added UserDefaults cleanup between tests
     - [x] Added frame processor state reset
     - [x] Added cleanup verification
     - [x] Improved test isolation

5. Frame Processing Tests (✅ Fixed)
   - Issue: Missing frame processing verification
   - Status: Fixed
   - Changes Made:
     - [x] Added frame processing test
     - [x] Added thread-safe frame counting
     - [x] Added frame simulation mechanism
     - [x] Added proper cleanup after frame processing

#### Test Suite Status
- BasicFrameProcessorTests: ✅ All tests passing
- CursorWindowTests: ✅ All tests passing
- H264VideoEncoderTests: ✅ All tests passing
- HLSManagerTests: ✅ All tests passing
- HLSSegmentWriterTests: ✅ All tests passing
- PlaylistGeneratorTests: ✅ All tests passing
- ScreenCaptureManagerTests: ✅ All tests passing
- VideoSegmentHandlerTests: ✅ All tests passing

#### Next Actions
1. ⏳ Add test coverage reporting
2. ⏳ Streamline test setup/teardown

#### Known Issues
1. ✅ Fixed: Duplicate MockSCStream declarations
2. ✅ Fixed: Actor isolation violations in frame processor access
3. ✅ Fixed: Stream property access issues in test environment
4. ✅ Fixed: Mock stream initialization missing required parameters
5. ✅ Fixed: Async/await warnings in stream methods

#### Recent Improvements
1. Added proper actor isolation with `FrameProcessorStore`
2. Implemented async helper methods for testing
3. Fixed stream property access with async getters
4. Improved mock stream initialization with required parameters
5. Fixed frame processor state management in tests
6. Added better error handling in stream methods
7. Added comprehensive cleanup mechanisms
8. Added frame processing verification
9. Improved test isolation and state management
10. Added descriptive assertion messages

#### Next Steps
1. Add test coverage reporting
2. Streamline test setup/teardown

## Next Steps

### Phase 4: UI Integration
The final phase will integrate the HTTP server with the main application UI:
- Server controls in the main application interface
- QR code generation for easy mobile connection
- Server status indicators in the UI
- Connection management interface
- Improved error handling and user feedback

## Known Issues and Limitations

1. Proper async test execution requires macOS 14.0 or later
2. Some test scenarios may require manual permission granting in system settings

## Coming Soon
1. iOS client app for viewing the stream
2. Integration of real-time metrics dashboard
3. Improved error handling and user feedback
4. Automated permission handling in test environment

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - See LICENSE file for details

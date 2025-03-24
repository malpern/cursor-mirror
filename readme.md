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

### Phase 4: iOS Client Implementation (🔄 In Progress)
- Core model layer (✅ Completed)
  - ConnectionState for managing connection status
  - DeviceInfo for representing discovered devices
  - StreamConfig for managing streaming configuration
- Connection infrastructure (✅ Completed)
  - CloudKit integration for device discovery
  - Connection management with proper state transitions
  - Device registration and discovery
- ViewModels (✅ Completed)
  - ConnectionViewModel for device discovery and connection management
  - UI state management with proper Swift 6 concurrency
- UI Components (⏱️ Planned)
  - Device discovery view
  - Connection status view
  - Video player interface
- Testing (✅ Completed)
  - Comprehensive test suite for models
  - Mocks for CloudKit and network operations
  - Proper test isolation using dependency injection

## Recent Improvements

- Added iOS client with model layer and connection infrastructure
- Implemented CloudKit-based device discovery for iOS client
- Created robust testing infrastructure with isolated test environment
- Fixed persistence issues with proper UserDefaults handling
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

- macOS 14.0 or later (for macOS app)
- iOS 17.0 or later (for iOS client)
- Xcode 15.0 or later
- Swift 6.0.3 or later

## Quick Start

1. Clone and build:
```bash
git clone https://github.com/yourusername/cursor-window.git
cd cursor-window
swift build
```

2. Launch and use macOS app:
   - Grant screen recording permission when prompted
   - Use Preview tab to position capture viewport
   - Use Encoding tab to configure and start streaming
   - Access HLS stream at the configured URL

3. Launch and use iOS client:
   - Grant necessary CloudKit permissions when prompted
   - Discover available devices on the same iCloud account
   - Connect to a streaming device
   - View the streamed content

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

iOS/
└── CursorMirrorClient/        # iOS client app
    ├── CursorMirrorClient.xcodeproj/  # Xcode project
    └── CursorMirrorClient/     # Main app source
        ├── Models/            # Data models for iOS client
        │   ├── ConnectionState.swift  # Connection state management
        │   ├── DeviceInfo.swift       # Device information
        │   └── StreamConfig.swift     # Stream configuration
        ├── ViewModels/        # View models for iOS client
        │   └── ConnectionViewModel.swift  # Device discovery and connection
        ├── Views/             # SwiftUI views (In Progress)
        └── Tests/             # Test suite for iOS client
            ├── ConnectionStateTests.swift
            ├── DeviceInfoTests.swift
            └── StreamConfigTests.swift
```

## Development

### Testing

### Current Test Status
- ✅ Core test suites are passing
- ✅ iOS client test suites are passing
- ✅ Manual testing confirms core functionality:
  - Screen capture working
  - Frame rate limiting effective
  - QoS optimization in place
  - HTTP server operational
  - HLS streaming functional
  - Device discovery working
  - Stream configuration persistence functioning

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - See LICENSE file for details

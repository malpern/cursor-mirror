# CursorWindow

A macOS application for capturing and streaming screen content with HLS (HTTP Live Streaming) support.

## Current Status

✅ **Completed Features**
- Screen capture with customizable viewport
  - Draggable viewport with iPhone 15 Pro dimensions (393x852 pixels)
  - Keyboard shortcuts and menu controls
  - Works across all spaces and full-screen apps
- Real-time H.264 video encoding
  - Thread-safe frame processing
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
  - Phase 1: Core Server Implementation ✅
    - ✅ Add Vapor dependency
    - ✅ Create `HTTPServerManager` class with configuration options
    - ✅ Implement basic routing (health check, version endpoint)
    - ✅ Add static file serving capability
    - ✅ Write tests for server functionality
  - Phase 2: HLS Integration ✅
    - ✅ Create HLS endpoint routes
    - ✅ Implement single-connection stream access control
    - ✅ Add connection timeout handling
    - ✅ Implement playlist generation
      - ✅ Master playlist with quality options
      - ✅ Media playlist with segments
      - ✅ Proper segment sequence handling
    - ✅ Set up video segment handling
      - ✅ Segment creation from H264 stream
      - ✅ Segment storage and cleanup
      - ✅ Segment delivery with proper headers
    - ✅ Write integration tests

🚧 **In Progress**
  - Phase 3: Advanced Features
    - [ ] Add authentication
    - [ ] Implement CORS support
    - [ ] Add request logging
    - [ ] Implement rate limiting
    - [ ] Create admin dashboard
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
├── CursorWindow/         # Main application code
└── CursorWindowCore/     # Core functionality
    ├── HLS/              # Core HLS implementation
    │   ├── HLSManager    # HLS streaming management
    │   ├── HLSTypes      # Common HLS data structures
    │   ├── TSSegmentWriter # MPEG-TS segment creation
    │   └── M3U8PlaylistGenerator # Core playlist generation
    ├── HTTP/             # HTTP server components
    │   ├── HTTPServerManager # Vapor server configuration
    │   ├── HLSStreamManager # Stream access control
    │   ├── HLSPlaylistGenerator # HTTP-specific playlist generation
    │   └── VideoSegmentHandler # Segment delivery
    ├── Capture/          # Screen capture components
    └── Encoding/         # Video encoding components
```

## Development

### Testing
- Comprehensive test suite with 59 tests across all components:
  - HLS streaming and segment management (12 tests)
  - H.264 video encoding (6 tests)
    - Basic encoding validation
    - Error handling and edge cases
    - Memory management
    - Concurrent processing
    - Performance benchmarks
  - Frame processing (6 tests)
  - Screen capture (2 tests)
  - HTTP server and HLS integration (7 tests)
    - Server configuration tests
    - HLS streaming flow validation
    - Video segment handling
    - Proper lifecycle management
  - Playlist generation (5 tests)
  - UI components (12 tests, requires GUI)
- Run tests: `swift test`

Note: UI tests require a GUI environment and will be skipped when running headless.

### Test Infrastructure
- `VaporTestHelper` class for managing Vapor application lifecycle in tests
  - Proper async/await server startup and shutdown
  - Resource cleanup with appropriate timing
  - HLS content type configuration
  - Temporary directory management
  - Debug logging for test tracing

### HLS Features
- Configurable segment duration and playlist length
- Automatic segment rotation and cleanup
- Support for multiple variant streams
- Event and VOD playlist generation
- Base URL configuration for flexible deployment
- Improved segment timing accuracy
- Enhanced error handling and recovery

### Performance Features
- Background frame processing
- 60fps UI update throttling
- Metal-accelerated rendering
- Debounced controls
- Proper task cancellation
- Efficient segment management
- Memory-optimized frame handling
- Thread-safe video encoding

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[Your license information here]

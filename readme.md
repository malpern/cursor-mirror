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
    │   ├── AdminController # Admin dashboard controller
    │   ├── AuthenticationManager # Authentication handling
    │   └── VideoSegmentHandler # Segment delivery
    ├── Capture/          # Screen capture components
    └── Encoding/         # Video encoding components
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

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[Your license information here]

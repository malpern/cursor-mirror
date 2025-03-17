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
  - Phase 4: Performance & Security
    - Optimize segment delivery with caching
    - Implement byte range requests for segments
    - Add SSL/TLS support with HTTPS redirects
    - Add monitoring and metrics with Prometheus
    - Implement comprehensive performance tests
    - Add security best practices:
      - Content Security Policy (CSP) configuration
      - Secure headers middleware
      - Request validation and sanitization
      - DoS protection middleware
      - Input size validation
  - Phase 5: UI Integration
    - Server controls in main application interface
    - QR code generation for mobile device connections
    - Server status indicators and visualization
    - Stream URL management and sharing
    - Connection monitoring and management
    - Integrated admin dashboard access

🚧 **Future Development**
  - iOS client app for stream playback
  - Additional stream formats (RTMP, WebRTC)
  - Stream quality presets
  - Custom viewport dimensions
  - Remote control capabilities

## iOS Client App Development Plan

The iOS client app will serve as a simple viewer application for CursorWindow streams, limited to a single viewer connection at a time.

### Core Requirements
- Create a minimalist SwiftUI-based iOS app with iOS 17+ target
- Implement HLS stream player using AVPlayer 
- Support single concurrent connection (enforce on server side)
- Focus on reliable, stable playback with minimal latency
- Use iCloud for seamless device discovery and authentication

### Implementation Plan
1. **iCloud Integration & Device Discovery**
   - Authenticate with iCloud account (same account on macOS and iOS)
   - Automatic discovery of available CursorWindow instances on user's devices
   - No manual URL entry or QR code scanning required
   - Simple device selection if multiple sources are available
   - Background synchronization of connection details

2. **Playback Functionality**
   - Full-screen video player with native controls
   - Stream quality/resolution display
   - Network quality indicator
   - Basic playback controls (play/pause, volume)
   - Portrait and landscape orientation support
   - One-tap connection to available stream

3. **Optional Enhancements** (if time allows)
   - Picture-in-Picture support
   - Background audio playback
   - Simple network diagnostics
   - Stream priority settings when multiple sources available
   - Connection handoff between different networks (Wi-Fi to cellular)

### Technical Approach
- **Architecture**: Simple MVVM with SwiftUI
- **Minimum iOS Version**: iOS 17.0
- **Key Frameworks**:
  - SwiftUI for UI components
  - AVFoundation/AVKit for video playback
  - CloudKit for iCloud integration and device discovery
  - Network framework for connection management
- **Design Focus**: Zero-configuration experience with minimal user intervention
- **Performance Priority**: Connection reliability and playback stability

The iOS client app will provide a nearly effortless connection experience - just sign in with your iCloud account on both devices, and the connection happens automatically. This eliminates all manual configuration steps, greatly simplifying the user experience.

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
   - Use Server tab to start the HTTP server and get stream access
   - Access HLS stream at the provided URL or scan the QR code with a mobile device

## Project Structure

```
Sources/
├── CursorWindow/         # Main application code
│   ├── Views/            # SwiftUI views
│   ├── ViewModels/       # View models for SwiftUI
│   └── Utilities/        # Helper classes and utilities
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
- Comprehensive test suite with 80+ tests across all components:
  - HLS streaming and segment management
  - H.264 video encoding
  - Frame processing
  - Screen capture
  - HTTP server and HLS integration
  - Admin dashboard functionality
  - Authentication and security
  - Performance and load testing
  - UI and integration testing
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
- SSL/TLS support with automatic self-signed certificates
- Performance optimizations for segment delivery
- Prometheus metrics for monitoring

#### UI Integration
- Tabbed interface with Preview, Encoding, and Server controls
- Server configuration with hostname, port, and SSL options
- Stream status indicators with real-time updates
- QR code generation for easy mobile device connections
- Direct access to admin dashboard from the app
- Clipboard integration for sharing stream URLs

#### Video Segment Optimization
- In-memory caching of segment data to reduce disk I/O
- Support for HTTP range requests (partial content)
- Efficient buffer management with NIO ByteBuffer
- Improved HTTP headers for caching and content negotiation
- Asynchronous segment cleanup operations

#### Monitoring & Metrics
- Prometheus integration for metrics collection
- Request counts, durations, and status codes
- Active connection tracking
- Segment size histograms by quality level
- Configurable metrics collection interval
- Optional metrics endpoint for Prometheus scraping

## Future Development

- Additional stream formats (RTMP, WebRTC)
- Stream quality presets for different use cases
- Custom viewport dimensions
- Remote control capabilities
- Cloud integration options

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[Your license information here]

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
- CloudKit Integration
  - Server-side CloudKit implementation
    - CloudKit manager for iCloud communication
    - Device discovery through iCloud private database
    - Network address detection and monitoring
    - User identity verification
    - Server instance broadcasting
  - Authentication enhancements
    - iCloud authentication method
    - Improved session management
    - Single-viewer enforcement
    - CloudKit middleware for authentication
    - Enhanced streaming session control

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

## Server-Side iCloud Integration (✅ Completed)

The server component now includes the following CloudKit integration features:

### CloudKit Integration
- CloudKit framework integration for iCloud operations
- `CloudKitManager` class for managing device broadcasting
- Server record type for sharing connection details
- Private CloudKit database for secure communication
- Background refresh for status updates

### Server Identity & Discovery
- Unique server identifier generation and persistence
- Server availability broadcasting via CloudKit
- Automatic network address detection
- Real-time network change monitoring
- Server name customization

### Authentication Enhancements
- Extended `AuthenticationManager` with iCloud support
- `CloudKitAuthMiddleware` for iCloud identity verification
- Single-viewer access control
- Enhanced session management
- Configurable authentication methods

### Network Management
- `NetworkAddressDetector` for automatic IP address discovery
- Support for multiple interfaces and address types
- Public IP detection
- Network path monitoring for connection changes
- Address prioritization for connection reliability

### Security Improvements
- Enhanced error handling with `CloudKitError` type
- Improved session timeout and cleanup
- Structured notification system for status changes
- Entitlements for CloudKit and network capabilities

This integration enables zero-configuration connections between devices using the same iCloud account, eliminating the need for manual URL entry or QR code scanning when using the upcoming iOS client app.

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later
- iCloud account (for CloudKit features)

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
   - For iCloud discovery, ensure you're signed into the same iCloud account on both devices

## Project Structure

```
Sources/
├── CursorWindow/         # Main application code
│   ├── Views/            # SwiftUI views
│   ├── ViewModels/       # View models for SwiftUI
│   ├── CloudKit/         # CloudKit integration components
│   │   ├── CloudKitManager      # iCloud operations handling
│   │   ├── NetworkAddressDetector # IP address detection
│   │   ├── CloudKitError        # Error handling
│   │   └── ServerInstance       # Data model for server instances
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
    │   ├── Authentication/ # Authentication components
    │   │   ├── AuthenticationManager # Authentication handling
    │   │   ├── CloudKitAuthMiddleware # iCloud authentication
    │   │   └── ProtectedRouteMiddleware # Route protection
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
- Authentication (Basic, Token, API Key, iCloud)
- CORS support with configurable policies
- Request logging with filtering and levels
- Rate limiting with multiple strategies
- Admin dashboard for monitoring and management
- SSL/TLS support with automatic self-signed certificates
- Performance optimizations for segment delivery
- Prometheus metrics for monitoring
- Single-viewer mode with iCloud authentication

#### UI Integration
- Tabbed interface with Preview, Encoding, and Server controls
- Server configuration with hostname, port, and SSL options
- Stream status indicators with real-time updates
- QR code generation for easy mobile device connections
- Direct access to admin dashboard from the app
- Clipboard integration for sharing stream URLs
- iCloud status indicators and controls

#### CloudKit Integration
- Zero-configuration device discovery
- Automatic network address management
- iCloud identity verification
- Server broadcasting to private CloudKit database
- Real-time status synchronization
- Network path monitoring
- Enhanced error handling

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

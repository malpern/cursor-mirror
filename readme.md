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
- HLS streaming implementation
  - MPEG-TS segment generation with proper timing
  - M3U8 playlist management (Master, Media, Event, VOD)
  - Efficient segment rotation and cleanup
  - Variant stream support
  - Async/await support for thread safety

🚧 **In Progress**
- Local HTTP server for stream distribution
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
    ├── HLS/             # HLS streaming implementation
    │   ├── HLSManager   # Stream management and segment control
    │   ├── TSSegmentWriter  # MPEG-TS segment handling
    │   └── PlaylistGenerator # M3U8 playlist generation
    ├── Capture/         # Screen capture components
    └── Encoding/        # Video encoding components
```

## Development

### Testing
- Comprehensive test suite for all components
  - HLS streaming and segment management
  - Playlist generation and validation
  - Frame processing and encoding
- UI tests for viewport and controls
- Performance tests for frame processing
- Run tests: `swift test`

Note: UI tests require a GUI environment and will be skipped when running headless.

### HLS Features
- Configurable segment duration and playlist length
- Automatic segment rotation and cleanup
- Support for multiple variant streams
- Event and VOD playlist generation
- Base URL configuration for flexible deployment

### Performance Features
- Background frame processing
- 60fps UI update throttling
- Metal-accelerated rendering
- Debounced controls
- Proper task cancellation
- Efficient segment management

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[Your license information here]

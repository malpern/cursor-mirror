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
  - MPEG-TS segment generation
  - M3U8 playlist management
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
    ├── Capture/         # Screen capture components
    └── Encoding/        # Video encoding components
```

## Development

### Testing
- Comprehensive test suite for all components
- UI tests for viewport and controls
- Performance tests for frame processing
- Run tests: `swift test`

Note: UI tests require a GUI environment and will be skipped when running headless.

### Performance Features
- Background frame processing
- 60fps UI update throttling
- Metal-accelerated rendering
- Debounced controls
- Proper task cancellation

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

[Your license information here]

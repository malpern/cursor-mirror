# CursorWindow

A macOS application for capturing and streaming screen content with HLS (HTTP Live Streaming) support.

## Features

- Screen capture with customizable viewport
- Draggable viewport with keyboard shortcuts and menu controls
- HLS streaming with adaptive bitrate support
- Real-time H.264 video encoding
- Configurable encoding settings (frame rate, bitrate)
- Preview mode for capture area
- Tab-based interface for preview and encoding controls

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/cursor-window.git
cd cursor-window
```

2. Build and run using Xcode or Swift Package Manager:
```bash
swift build
```

## Usage

1. Launch the application
2. Grant screen recording permission when prompted
3. Use the Preview tab to position the capture viewport:
   - Drag the viewport to desired position
   - Use Cmd + Arrow keys for precise positioning
   - Use View > Reset Position to center the viewport
4. Switch to the Encoding tab to configure and start streaming:
   - Adjust frame rate and bitrate as needed
   - Click "Start Encoding" to begin streaming
   - Access HLS stream at the configured URL

## Development

### Project Structure

- `Sources/CursorWindow/`: Main application code
- `Sources/CursorWindowCore/`: Core functionality
  - `HLS/`: HLS streaming implementation
  - `Capture/`: Screen capture components
  - `Encoding/`: Video encoding components
- `Tests/`: Unit and UI tests

### Testing

Run the test suite:
```bash
swift test
```

Note: UI tests require a GUI environment and will be skipped when running in a headless environment.

### Key Components

- **HLSManager**: Manages HLS streaming, segment creation, and playlist generation
- **TSSegmentWriter**: Handles writing encoded video data to MPEG-TS segments
- **PlaylistGenerator**: Generates M3U8 playlists for HLS streaming
- **DraggableViewport**: UI component for selecting the capture area
- **H264VideoEncoder**: Real-time H.264 video encoding

## License

[Your license information here]

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

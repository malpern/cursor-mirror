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

### Phase 2: Screen Capture & Streaming (🚧 In Progress)
- [✅] Screen capture of viewport region using ScreenCaptureKit
  - ✅ Basic permission handling implemented
  - ✅ Test infrastructure set up
  - ✅ Frame capture implementation completed
  - ✅ Integration tests completed and passing
- [ ] Real-time H.264 video encoding with AVFoundation/VideoToolbox
- [ ] HLS stream generation with segmented .ts files
- [ ] Local HTTP server for stream distribution
- [ ] iOS client app for stream playback

## Architecture

```mermaid
flowchart LR
    A[Screen Capture (ScreenCaptureKit)]
    B[Video Encoder (AVFoundation/VideoToolbox)]
    C[HLS Segmentation (AVAssetWriter)]
    D[HTTP Server (Vapor/Custom)]
    E[iOS Client (AVPlayer)]
    
    A --> B
    B --> C
    C --> D
    D --> E
```

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

### 3. Video Encoding (📅 Planned)
- [ ] 3.1. Setup AVFoundation/VideoToolbox pipeline
- [ ] 3.2. Implement H.264 encoding
- [ ] 3.3. Test encoding performance

### 4. HLS Implementation (📅 Planned)
- [ ] 4.1. Implement video segmentation
- [ ] 4.2. Generate M3U8 playlists
- [ ] 4.3. Test segment generation

### 5. HTTP Server (📅 Planned)
- [ ] 5.1. Setup lightweight HTTP server
- [ ] 5.2. Configure static file serving
- [ ] 5.3. Test network accessibility

### 6. Integration & Testing (📅 Planned)
- [ ] 6.1. End-to-end testing
- [ ] 6.2. Performance optimization
- [ ] 6.3. Error handling
- [ ] 6.4. iOS client testing

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later (for development)
- Swift 5.9 or later

## Getting Started

1. Clone the repository
```bash
git clone https://github.com/yourusername/cursor-mirror.git
```

2. Open the project in Xcode
```bash
cd cursor-mirror
open cursor-window.xcodeproj
```

3. Build and run (⌘R)

## Usage

### Current Features
1. Launch the app
2. Grant screen recording permission when prompted
3. Drag the blue border to position the viewport
4. Click through the center area to interact with windows underneath
5. Use Cmd+Q or the menu bar to quit
6. View real-time screen capture within the app

### Coming Soon
1. Local network streaming
2. iOS client app for viewing the stream

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
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

## Recent Improvements

- Enhanced `FrameCaptureManager` with proper task cancellation support to prevent race conditions
- Implemented background processing for frame handling to improve UI responsiveness
- Added frame rate limiting (60fps cap) to prevent UI thread overload
- Implemented Metal-accelerated rendering with `drawingGroup()` for better performance
- Added debouncing for UI controls like the frame rate slider to improve responsiveness
- Improved test reliability by making tests more robust in different environments
- Fixed type compatibility issues between test mocks and production code
- Ensured proper resource cleanup with deinitializers to prevent memory leaks
- All tests now pass successfully

## Performance Optimizations

- **Background Processing**: Frame processing now occurs on a dedicated background queue
- **Throttled Updates**: UI updates are limited to 60fps maximum to maintain responsiveness
- **Metal Rendering**: Using Metal-accelerated rendering for captured frames display
- **Debounced Controls**: UI controls use debouncing to prevent excessive processing
- **Task Management**: Proper cancellation of ongoing tasks when starting new operations

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

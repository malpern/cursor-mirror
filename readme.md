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

### Phase 3: Enhanced Functionality (✅ Completed)
- Touch emulation controls (✅ Completed)
  - iOS client touch event capture
  - Event transmission via HTTP API
  - Mouse event simulation on macOS
  - Support for tap, drag, and multi-touch

### Phase 4: iOS Client Implementation (✅ Completed)
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
- UI Components (✅ Completed)
  - Device discovery view (✅ Completed)
    - Device search functionality
    - Connection status visualization
    - Error handling and retry mechanism
    - Detailed help and troubleshooting guides
  - Video player interface (✅ Completed)
    - Video streaming with HLS
    - Quality selection (Auto, 480p, 720p, 1080p)
    - Fullscreen mode with gesture support
    - Detailed stream statistics
    - Touch controls for remote interaction
  - Settings view (✅ Completed)
    - Connection settings management
    - Video quality and buffering configuration
    - Touch control sensitivity and behavior
    - Appearance customization options
    - CloudKit settings synchronization
- Testing (✅ Completed)
  - Comprehensive test suite for models
  - Mocks for CloudKit and network operations
  - Proper test isolation using dependency injection
  - Robust synchronous testing approach for async operations

  Future development:
  * Investigate including sound, so sound played on the desktop can be heard on the iphone.

## Recent Improvements

### March 2025 Update
- **UI and UX Enhancements**:
  - Fixed Start/Stop Capture button toggle state reactivity with local state management
  - Made UI buttons change color immediately when pressed using a dual-state approach
  - Added proper state synchronization between main window and menu bar
  - Improved local state feedback for all interactive elements
  - Start Server button is now disabled until capture is started
  - Start Capture button turns red immediately when pressed
  - Server button enables automatically when capture is active

- **Application Lifecycle Improvements**:
  - Enhanced quit functionality with reliable application termination
  - Added failsafe mechanisms to prevent application hang during shutdown
  - Implemented proper cleanup of resources during application termination
  - Fixed CloudKit-related issues that could cause shutdown delays
  - Added CloudKit operation timeouts to prevent hangs during server shutdown

- **State Management and Persistence**:
  - Better handling of capture state throughout the application
  - Added UserDefaults persistence for app state
  - Improved error handling and recovery for failed operations
  - Enhanced synchronization between UI components
  - Added notification-based state propagation for consistent UI updates

### Previous Updates
- **CloudKit and Connectivity**:
  - Added CloudKit Device Registration with IP Address
  - Implemented automatic server IP registration in CloudKit
  - Added server status tracking (online/offline)
  - Enhanced iOS client to use server's actual IP address
  - Improved connection reliability across different networks
  - Added proper error handling for CloudKit operations

- **Core Architecture Improvements**:
  - Fixed build errors and improved encoder implementation
  - Resolved duplicate ViewportSize implementations
  - Fixed ambiguous VideoEncoder protocol declarations
  - Reorganized code structure with proper file organization
  - Updated H264VideoEncoder implementation with ObservableObject support
  - Fixed formatDescription property and encoding initialization
  - Improved HLSEncodingAdapter integration
  - Fixed tests to use the new encoder interface

- **UI Enhancements**:
  - Enhanced menu bar UI with consistent styling and workflow
  - Converted viewport toggle to a button for UI consistency
  - Reorganized buttons to follow logical workflow sequence
  - Made all buttons use consistent styling and behavior
  - Added proper server state handling in the UI
  - Improved settings gear icon appearance and placement

- **Server and Performance**:
  - Improved server management and shutdown
  - Added proper async/await handling for server operations
  - Fixed server state tracking and button responsiveness
  - Added robust shutdown process to prevent assertion errors
  - Enhanced error handling throughout the application
  - Refactored frame processing architecture
  - Created unified `FrameProcessor` protocol for consistent frame handling
  - Improved `BasicFrameProcessor` with better performance tracking
  - Added thread-safe statistics collection with exponential moving average
  - Enhanced frame dropping detection for better performance monitoring

- **Code Quality and Testing**:
  - Fixed circular dependencies
  - Moved shared types to appropriate modules
  - Improved code organization and modularity
  - Reduced coupling between core components
  - Enhanced test suite reliability and coverage
  - Fixed async/await handling in ViewportTests
  - Improved main thread handling for UI operations
  - Added proper test setup/teardown with async support
  - Fixed singleton pattern issues in TouchEventController tests
  - Added comprehensive test coverage for all components
  - Improved test robustness with proper error handling

- **iOS Client Improvements**:
  - Added comprehensive test coverage for touch emulation
  - Added CloudKit Settings Sync for iOS client
  - Simplified and fixed iOS client Settings screen
  - Replaced complex NavigationSplitView with more reliable NavigationStack
  - Fixed UI component rendering issues with proper color handling
  - Standardized appearance handling across light and dark modes
  - Improved UI responsiveness and reliability
  - Added iOS client with model layer and connection infrastructure
  - Enhanced DeviceDiscoveryView with advanced features
  - Enhanced PlayerView with advanced streaming features

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
   - Adjust quality settings as needed for your network
   - Use touch controls to interact with remote content

## Project Structure

```
Sources/
├── CursorWindowCore/           # Core functionality module
│   ├── SharedTypes.swift       # Shared protocols and types
│   ├── ScreenCaptureManager.swift  # Screen capture with frame rate limiting
│   ├── BasicFrameProcessor.swift   # Frame processing with QoS optimization
│   ├── H264VideoEncoder.swift  # Thread-safe video encoding
│   ├── TouchEmulation/        # Touch event handling
│   │   ├── TouchEventController.swift  # Touch event processing
│   │   └── TouchEventRoute.swift      # HTTP API endpoint
│   └── HTTP/                   # HTTP server components
│       ├── HTTPServerManager.swift  # Improved server with proper shutdown
│       ├── HLS/                # HLS streaming components
│       │   ├── HLSEncodingAdapter.swift  # Encoder integration
│       │   ├── HLSStreamManager.swift    # Stream management
│       │   └── HLSStreamController.swift # Stream control endpoints
│       ├── AuthenticationManager.swift
│       ├── RequestLog.swift
│       ├── ServerConfig.swift
│       └── Middleware/
│           ├── LoggingMiddleware.swift
│           └── AuthMiddleware.swift
└── CursorWindow/              # Main app module
    ├── CursorWindowApp.swift
    ├── AppDelegate.swift      # Improved app lifecycle management
    ├── StatusBar/             # Menu bar components
    │   └── StatusBarController.swift  # Menu bar handling
    └── Views/
        ├── MenuBarView.swift  # Improved UI with consistent styling
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
        ├── Views/             # SwiftUI views
        │   ├── DeviceDiscoveryView.swift  # Device discovery and selection
        │   ├── PlayerView.swift   # Video player with streaming controls
        │   └── ConnectionStatusView.swift  # Connection status visualization
        └── Tests/             # Test suite for iOS client
            ├── ConnectionStateTests.swift
            ├── DeviceInfoTests.swift
            └── StreamConfigTests.swift
```

## Development

### Testing

Run the test suite:
```bash
swift test
```

### Current Test Status
- ✅ All tests are passing (40 tests)
  - H264VideoEncoder tests updated to use new encoder interface
  - TouchEventController tests
  - TouchEventRoute tests
  - ViewportManager tests
  - HLSManager tests
  - PlaylistGenerator tests
  - VideoSegmentHandler tests
  - BasicFrameProcessor tests
  - MenuBarView tests
  - Viewport tests
- ✅ iOS client test suites are passing
- ✅ Manual testing confirms core functionality:
  - Screen capture working
  - Video encoding fully functional with improved interface
  - Frame rate limiting effective
  - QoS optimization in place
  - HTTP server operational with improved shutdown process
  - HLS streaming functional
  - Device discovery working
  - Stream configuration persistence functioning
  - Touch event forwarding functional
  - Stream quality adjustment working
  - UI improved with consistent styling and button workflow

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - See LICENSE file for details

## Development Roadmap (April 2025)

### Issue Assessment and Remediation Plan

#### Current Issues

##### Critical Issues
1. **Actor Isolation Conflicts**: 
   - `H264VideoEncoder` has inconsistent isolation patterns
   - `EncodingSettings` access patterns mix direct and async approaches
   - Multiple compiler warnings about actor isolation

2. **Inconsistent State Management**:
   - Multiple independently managed copies of settings
   - Asynchronous updates not properly propagated

3. **Build Failures**:
   - Type mismatches when passing settings between components
   - Missing or outdated method references

##### Major Issues
1. **UI Architecture Problems**:
   - Duplicate UI implementation between views
   - Inconsistent binding patterns
   - Mixed state management approaches

2. **View Model Integration**:
   - Improper initialization of view models
   - Inconsistent usage of environment objects

3. **Error Handling Gaps**:
   - Inconsistent error propagation
   - Missing user feedback for failures

##### Minor Issues
1. **Code Redundancy**:
   - Multiple overlapping view components
   - Duplicate initialization logic

2. **Documentation Gaps**:
   - Missing inline documentation
   - Unclear architecture explanation

3. **Test Coverage**:
   - Outdated tests that use old patterns
   - Missing tests for error cases

#### Prioritized Issue List

##### Priority 1 (Must Fix)
1. ✅ Fix actor isolation conflicts in `H264VideoEncoder` and related components
2. ✅ Resolve build failures from type mismatches
3. ✅ Consolidate state management pattern for encoding settings
4. ✅ Fix HLSEncodingAdapter interface mismatch with H264VideoEncoder
5. ✅ Fix FrameProcessor protocol conformance issues
6. ✅ Fix async Task handling in SwiftUI views

##### Priority 2 (Important)
1. ✅ Unify UI architecture across view components
2. ✅ Fix view model initialization and integration
3. 🔄 Implement consistent error handling
4. ✅ Fix duplicate UI component declarations
5. ✅ Fix async initialization in preview contexts

##### Priority 3 (Necessary)
1. 🔄 Remove code redundancies
2. ⏳ Update and expand documentation
3. ⏳ Fix and expand test coverage
4. ✅ Fix mock implementation protocol conformance

#### Remediation Plan

##### Phase 1: Critical Fixes (Estimated: 4-6 hours)
1. **Fix Actor Isolation**: ✅
   - ✅ Update `H264VideoEncoder` to consistently use isolated properties
   - ✅ Implement proper nonisolated access patterns
   - ✅ Add clear actor boundaries with MainActor annotations

2. **Resolve Type Mismatches**: ✅
   - ✅ Standardize on async property access for actor-isolated objects
   - ✅ Update all binding patterns to handle async access
   - ✅ Fix initialization patterns for view models

3. **Unify State Management**: ✅
   - ✅ Consolidate `EncodingSettings` usage to a single source of truth
   - ✅ Implement proper propagation of settings changes
   - ✅ Add atomic update functions for settings

4. **Fix Interface Mismatches**: ✅
   - ✅ Update `HLSEncodingAdapter` to use new H264VideoEncoder interface
   - ✅ Fix ViewportSize.defaultSize access in AppDelegate
   - ✅ Update duplicate ViewportSize definitions
   - ✅ Implement FrameProcessor protocol in processors

5. **Fix Async Task Handling**: ✅
   - ✅ Fix `Task` usage in SwiftUI views
   - ✅ Use appropriate MainActor annotations to prevent isolation issues
   - ✅ Implement proper state tracking with onChange for async UI updates

##### Phase 2: Architecture Improvements (Estimated: 3-5 hours)
1. **Unify UI Components**: ✅
   - ✅ Create a single settings form component
   - ✅ Implement proper async bindings
   - ✅ Remove duplicate view implementations

2. **Refactor View Models**: ✅
   - ✅ Standardize initialization patterns
   - ✅ Implement proper environment object usage
   - ✅ Fix preview providers

3. **Error Handling**: 🔄
   - 🔄 Implement consistent error flow
   - ⏳ Add user feedback for failures
   - ⏳ Handle edge cases properly

4. **Fix Duplicate Declarations**: ✅
   - ✅ Resolve duplicate implementations of EncodingControlView
   - ✅ Fix conflicting mock class declarations
   - ✅ Ensure proper optional handling for environment objects

5. **Improve Asynchronous Preview Support**: ✅
   - ✅ Add shared instances for view models to avoid async initialization in previews
   - ✅ Use factory methods for preview providers

##### Phase 3: Cleanup and Documentation (Estimated: 2-3 hours)
1. **Code Cleanup**: 🔄
   - 🔄 Remove redundant components
   - ⏳ Fix naming inconsistencies
   - ⏳ Improve code organization

2. **Documentation**: ⏳
   - ⏳ Add comprehensive inline documentation
   - ⏳ Update architecture explanation
   - ⏳ Document known limitations

3. **Testing**: ⏳
   - ⏳ Update tests for new patterns
   - ⏳ Add missing test cases
   - ⏳ Validate all user flows

4. **Mock Implementations**: ✅
   - ✅ Fix MockFrameProcessor to properly implement BasicFrameProcessorProtocol
   - ✅ Fix MockEncodingProcessor to implement EncodingFrameProcessorProtocol
   - ✅ Update preview providers to handle async initialization

#### Implementation Progress

- **Phase 1.1**: ✅ Fixed primary actor isolation issues in `EncodingSettings` and `H264VideoEncoder`
- **Phase 1.2**: ✅ Updated binding patterns to use async access with Task-based updates
- **Phase 1.3**: ✅ Implemented unified settings form component with proper actor isolation
- **Phase 1.4**: ✅ Fixed HLSEncodingAdapter to use new H264VideoEncoder interface
- **Phase 1.5**: ✅ Fixed FrameProcessor protocol implementation in processors
- **Phase 1.6**: ✅ Fixed Task usage in SwiftUI views to prevent mutating self errors
- **Phase 2.1**: ✅ Consolidated UI architecture with shared EncodingSettingsFormView
- **Phase 2.2**: ✅ Standardized view model initialization with proper MainActor annotations
- **Phase 2.3**: 🔄 In progress - Error handling improvements
- **Phase 2.4**: ✅ Fixed duplicate view declarations (EncodingControlView)
- **Phase 2.5**: ✅ Added shared instances for view models to avoid async initialization in previews
- **Phase 3.1**: 🔄 In progress - Code cleanup (removed duplicate code in BasicFrameProcessor)
- **Phase 3.2**: ⏳ Not started - Documentation updates
- **Phase 3.3**: ⏳ Not started - Test updates
- **Phase 3.4**: ✅ Fixed mock implementation protocol conformance

**Current Build Status**: 🎉 **SUCCESS!** The application now builds successfully. We've addressed all the critical issues:

1. ✅ Fixed the HLSEncodingAdapter to use the new H264VideoEncoder interface
2. ✅ Resolved ambiguous method calls in H264VideoEncoder by renaming methods
3. ✅ Removed duplicate EncodingControlView implementation from MainView.swift
4. ✅ Fixed ViewportSize usage in DraggableViewport.swift to use the proper ViewportSize.defaultSize() method
5. ✅ Fixed mock implementations to conform to their protocols
6. ✅ Fixed the environment object optional unwrapping in MainView
7. ✅ Fixed preview providers to handle async initialization properly
8. ✅ Made processors conform to FrameProcessor protocol
9. ✅ Added shared instances for view models to avoid async initialization issues
10. ✅ Fixed Task usage in SwiftUI views to prevent mutating self errors
11. ✅ Applied @MainActor where needed to ensure proper actor isolation

There are still several warnings about 'await' expressions with no async operations, but these do not prevent building and are not critical issues. They can be addressed in the cleanup phase.

The next steps should focus on:
1. Cleaning up the remaining warnings
2. Improving error handling
3. Expanding test coverage
4. Updating documentation to reflect all the architectural changes





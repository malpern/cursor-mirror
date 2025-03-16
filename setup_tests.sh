#!/bin/bash

# Create test directory structure
mkdir -p cursor-window/Tests/ScreenCaptureTests

# Create test target using xcodebuild
xcodebuild -project cursor-window.xcodeproj -target "CursorMirrorTests" -configuration Debug

# Add ScreenCaptureKit framework to project capabilities
/usr/libexec/PlistBuddy -c "Add :com.apple.security.screen-capture bool true" cursor-window/cursor_window.entitlements

echo "Test setup complete. Please open Xcode to configure the test target." 
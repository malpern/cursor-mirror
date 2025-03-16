# Draggable Viewport iOS App

This SwiftUI project implements a draggable blue viewport with fixed dimensions (393 x 852 points) that can be moved around the screen. The viewport currently displays placeholder content, but is designed to be easily updated to integrate streaming content in the future.

## Features

- Fixed-size viewport (393 x 852 points, matching iPhone 15 Pro dimensions)
- Smooth drag functionality to reposition the viewport
- Bounds checking to keep the viewport on-screen
- Reset button to return the viewport to center position
- Position coordinates display for debugging purposes

## Project Structure

- `DraggableViewportApp.swift`: The main app entry point
- `ContentView.swift`: The main view that hosts the draggable viewport
- `DraggableViewport.swift`: The implementation of the draggable viewport component

## How to Use

1. Clone or download the project
2. Open the project in Xcode
3. Build and run the app on an iOS simulator or device
4. Drag the blue viewport around to reposition it
5. Use the "Reset Position" button to return to the center

## Integrating Streaming Content

To replace the placeholder with actual streaming content:

1. Open `DraggableViewport.swift`
2. Find the overlay section with the "Stream goes here" text
3. Replace this placeholder with your streaming view component
4. Make sure your streaming content respects the viewport dimensions

Example:

```swift
.overlay(
    // Replace this with your streaming content
    YourStreamingView()
        .frame(width: viewportWidth, height: viewportHeight)
        .clipped()
)
```

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+

## Future Improvements

- Add zoom functionality
- Implement smooth animations during viewport transitions
- Add rotation gesture support
- Enhance with picture-in-picture capabilities

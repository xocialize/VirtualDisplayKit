# VirtualDisplayKit

[![Fork of DeskPad](https://img.shields.io/badge/fork_of-Stengo%2FDeskPad-blue)](https://github.com/Stengo/DeskPad)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Swift 5.9+](https://img.shields.io/badge/swift-5.9+-orange.svg)](https://swift.org)
[![macOS 13+](https://img.shields.io/badge/macOS-13+-blue.svg)]()

> **A Swift Package derived from [Stengo/DeskPad](https://github.com/Stengo/DeskPad).**
> DeskPad pioneered the use of `CGVirtualDisplay` for on-screen virtual display
> creation on macOS. VirtualDisplayKit extends that foundation into a modular,
> reusable Swift Package with video recording, RTMP-ready streaming output,
> and SwiftUI/AppKit view integrations. See [ATTRIBUTION.md](ATTRIBUTION.md)
> for a full breakdown of what is derived and what is original.

> [!WARNING]
> **This library uses Apple's private `CGVirtualDisplay` API.** Private APIs
> are not officially supported by Apple and may change between macOS versions.
> Apps using this library are **not suitable for App Store submission** without
> understanding and accepting the risk of rejection. This is intended for
> internal tools, development utilities, digital signage systems, and
> direct-distribution applications. See [SECURITY.md](SECURITY.md) for more.

A modular Swift Package for creating and managing virtual displays on macOS, with built-in support for recording and streaming. Designed for easy integration into existing applications, particularly useful for digital signage, remote desktop testing, streaming, and multi-monitor development scenarios.

## Features

- 🖥️ **Virtual Display Creation**: Create virtual displays that appear as real monitors to macOS
- 📺 **Live Display Streaming**: Stream virtual display content to your app using modern APIs
- 🎥 **Recording**: Record virtual display content to H.264/HEVC video files
- 📡 **Streaming Output**: Get encoded frames for RTMP/HLS streaming integration
- 🎨 **SwiftUI & AppKit Support**: Native views for both UI frameworks
- ⚙️ **Highly Configurable**: Customize resolution, refresh rate, HiDPI support, and more
- 🚀 **Modern Swift**: Built with Swift Concurrency, Combine, and modern best practices
- 📦 **Swift Package Manager**: Easy integration as a dependency

## Requirements

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add VirtualDisplayKit to your project by adding it as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(path: "../VirtualDisplayKit")
    // Or from a git repository:
    // .package(url: "https://github.com/yourusername/VirtualDisplayKit.git", from: "1.0.0")
]
```

Then add it to your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["VirtualDisplayKit"]
)
```

### Xcode Project

1. In Xcode, go to **File → Add Package Dependencies...**
2. Enter the package URL or path
3. Select your target and click **Add Package**

## Demo Application

A full-featured demo application is included in `VirtualDisplayDemo.xcodeproj`. Open it in Xcode to see all features in action:

- Virtual display creation with preset configurations
- Live preview with cursor tracking
- Recording to MP4/MOV files
- Streaming output with frame statistics

To run the demo:
1. Open `VirtualDisplayDemo.xcodeproj` in Xcode
2. Build and run (⌘R)

## Quick Start

### Simple Usage with VirtualDisplayController

The easiest way to use VirtualDisplayKit:

```swift
import VirtualDisplayKit

// Create a controller
let controller = VirtualDisplayController(preset: .standard1080p)

// Start the virtual display
controller.start()

// Create and show a preview window
let window = controller.createPreviewWindow()
window.makeKeyAndOrderFront(nil)

// When done, stop the display
controller.stop()
```

### SwiftUI Integration

```swift
import SwiftUI
import VirtualDisplayKit

struct ContentView: View {
    @StateObject private var virtualDisplay = VirtualDisplay(
        configuration: VirtualDisplayConfiguration(
            name: "My Display",
            maxWidth: 1920,
            maxHeight: 1080
        )
    )
    
    var body: some View {
        VStack {
            VirtualDisplayView(virtualDisplay: virtualDisplay) { point in
                // Handle tap - move cursor to that point
                virtualDisplay.moveCursor(to: point)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            HStack {
                Button("Start") {
                    virtualDisplay.start()
                }
                .disabled(virtualDisplay.isReady)
                
                Button("Stop") {
                    virtualDisplay.stop()
                }
                .disabled(!virtualDisplay.isReady)
            }
        }
        .padding()
    }
}
```

### Recording

Record virtual display content to video files:

```swift
let controller = VirtualDisplayController(preset: .standard1080p)
controller.start()

// Start recording with high quality settings
let outputURL = URL(fileURLWithPath: "/path/to/recording.mp4")
try controller.startRecording(to: outputURL, configuration: .highQuality)

// Later, stop recording
let finalURL = try await controller.stopRecording()
print("Recording saved to: \(finalURL)")
```

Available recording configurations:
- `.standard` - 30fps, 5Mbps H.264
- `.highQuality` - 60fps, 10Mbps H.264
- `.hevcHighEfficiency` - 30fps, 4Mbps HEVC

### Streaming

Get encoded frames for streaming to external services (Twitch, YouTube, custom RTMP):

```swift
let controller = VirtualDisplayController(preset: .standard1080p)
controller.start()

// Start streaming with RTMP-optimized settings
try controller.startStreaming(configuration: .rtmpStreaming) { data, presentationTime, isKeyFrame in
    // Send encoded H.264 data to your streaming server
    // data: Annex B formatted NAL units
    // presentationTime: CMTime for synchronization
    // isKeyFrame: true for I-frames
    
    yourRTMPClient.sendVideoFrame(data, timestamp: presentationTime, isKeyframe: isKeyFrame)
}

// Stop streaming
controller.stopStreaming()
```

Available streaming configurations:
- `.rtmpStreaming` - Optimized for Twitch/YouTube (4.5Mbps, 30fps)
- `.highQuality` - High quality streaming (8Mbps, 60fps)
- `.realtime` - Low latency for real-time apps (3Mbps, 1s keyframes)

### Advanced: Direct Frame Access

For custom processing, access raw frames directly:

```swift
let renderer = DisplayStreamRenderer(backend: .cgDisplayStream, showCursor: true)
renderer.configure(displayID: displayID, resolution: resolution, scaleFactor: scaleFactor)

// Get IOSurface frames
renderer.onFrameAvailable = { surface in
    // Use IOSurface for Metal/OpenGL rendering
}

// Get CVPixelBuffer frames (for VideoToolbox, Core Image, etc.)
renderer.onPixelBufferAvailable = { pixelBuffer in
    // Process with Core Image, VideoToolbox, etc.
}
```

## Configuration Options

### VirtualDisplayConfiguration

```swift
let configuration = VirtualDisplayConfiguration(
    name: "My Virtual Display",       // Display name shown in System Preferences
    maxWidth: 3840,                    // Maximum width in pixels
    maxHeight: 2160,                   // Maximum height in pixels
    physicalSizeMillimeters: CGSize(width: 600, height: 340), // Physical size for DPI
    vendorID: 0x3456,                  // Vendor ID for identification
    productID: 0x1234,                 // Product ID for identification
    serialNumber: 0x0001,              // Serial number
    hiDPIEnabled: true,                // Enable Retina/HiDPI modes
    refreshRate: 60,                   // Refresh rate in Hz
    displayModes: [                    // Available resolution modes
        DisplayMode(width: 1920, height: 1080, refreshRate: 60),
        DisplayMode(width: 1280, height: 720, refreshRate: 60),
    ],
    showCursor: true,                  // Show cursor in stream
    streamingBackend: .automatic       // Streaming technology to use
)
```

### Configuration Presets

```swift
// Standard 1080p
let config1 = VirtualDisplayConfiguration.preset1080p

// 4K resolution
let config2 = VirtualDisplayConfiguration.preset4K

// Digital signage (includes portrait modes)
let config3 = VirtualDisplayConfiguration.presetSignage
```

## Architecture

```
VirtualDisplayKit/
├── Package.swift                 # SPM package definition
├── Sources/
│   ├── CVirtualDisplayPrivate/   # C headers for private APIs
│   │   └── include/
│   │       └── CGVirtualDisplayPrivate.h
│   └── VirtualDisplayKit/
│       ├── Core/
│       │   ├── VirtualDisplay.swift           # Main display manager
│       │   ├── VirtualDisplayConfiguration.swift
│       │   ├── DisplayStreamRenderer.swift    # Stream rendering
│       │   ├── DisplayRecorder.swift          # Video recording
│       │   └── FrameOutputStream.swift        # Streaming output
│       ├── Views/
│       │   ├── VirtualDisplayView.swift       # SwiftUI view
│       │   └── VirtualDisplayNSView.swift     # AppKit view
│       ├── VirtualDisplayController.swift     # High-level controller
│       └── VirtualDisplayKit.swift            # Public exports
├── Tests/
│   └── VirtualDisplayKitTests/
├── VirtualDisplayDemo/           # Demo app source
└── VirtualDisplayDemo.xcodeproj  # Demo app project
```

## Use Cases

### Digital Signage Testing

Test your digital signage content without needing physical displays:

```swift
let controller = VirtualDisplayController(preset: .signage)
controller.start()

// Your signage app will see this as a real display
// Record a demo video
try controller.startRecording(to: demoURL, configuration: .highQuality)
```

### Multi-Monitor Development

Develop and test multi-monitor features on a single-screen machine:

```swift
// Create multiple virtual displays
let display1 = VirtualDisplay(configuration: VirtualDisplayConfiguration(name: "Virtual 1"))
let display2 = VirtualDisplay(configuration: VirtualDisplayConfiguration(name: "Virtual 2"))

display1.start()
display2.start()
```

### Streaming Integration

Integrate with OBS, streaming services, or custom solutions:

```swift
let stream = FrameOutputStream(configuration: .rtmpStreaming)
stream.configure(displaySize: resolution, scaleFactor: 2.0)

stream.onEncodedFrame = { data, time, isKeyFrame in
    // Send to RTMP server
    rtmpClient.publish(data: data, timestamp: time.seconds)
}

try stream.start()
```

## Important Notes

### Private API Usage

This library uses Apple's private `CGVirtualDisplay` API to create virtual displays. While this API has been stable for several years and is used by popular apps like BetterDisplay, be aware that:

- Private APIs are not officially supported by Apple
- They may change between macOS versions
- Apps using private APIs may face additional scrutiny for App Store submission

### Permissions

Your app will need screen recording permission to stream display content. This is handled automatically by macOS when using ScreenCaptureKit or CGDisplayStream.

### Known Limitations

- Virtual displays persist until the creating application terminates
- ScreenCaptureKit has some known issues with multiple virtual displays (we default to CGDisplayStream)
- HiDPI modes require appropriate configuration to work correctly

## License

MIT License - See LICENSE file for details.

## Credits

This project is a fork of and derivative work based on **[DeskPad](https://github.com/Stengo/DeskPad)** by [Bastian Andelefski](https://github.com/Stengo), licensed under MIT. DeskPad pioneered the use of `CGVirtualDisplay` for on-screen virtual display creation on macOS, and that approach is preserved at the core of VirtualDisplayKit.

See [ATTRIBUTION.md](ATTRIBUTION.md) for a complete breakdown of what is derived from DeskPad versus what is original to this project.

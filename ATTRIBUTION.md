# Attribution

VirtualDisplayKit is a derivative work of **DeskPad** by Bastian Andelefski.

- **Original project:** https://github.com/Stengo/DeskPad
- **Original author:** Bastian Andelefski ([@Stengo](https://github.com/Stengo))
- **Original license:** MIT
- **Original copyright:** © 2022 Bastian Andelefski

## Relationship to DeskPad

DeskPad is the foundation for virtual display creation and `CGDisplayStream`-based
preview functionality in this project. The `CGVirtualDisplayPrivate.h` private API
declarations and the core approach to managing `CGVirtualDisplay` instances were
derived from DeskPad's implementation.

### Files derived from DeskPad

- `Sources/CVirtualDisplayPrivate/include/CGVirtualDisplayPrivate.h` — private API
  declarations for `CGVirtualDisplay`
- `Sources/VirtualDisplayKit/Core/VirtualDisplay.swift` — core virtual display
  creation, configuration, and retry logic
- `Sources/VirtualDisplayKit/Core/DisplayStreamRenderer.swift` — `CGDisplayStream`
  setup and frame callback handling

## What VirtualDisplayKit adds

VirtualDisplayKit extends the original DeskPad concept with:

- A full Swift Package Manager module with a public API surface
- `DisplayRecorder` — records virtual display content to H.264/HEVC MP4/MOV files
  via `AVAssetWriter`
- `FrameOutputStream` — emits encoded H.264/HEVC Annex-B or raw `CVPixelBuffer`
  frames for RTMP streaming, OBS integration, or custom pipelines, via
  `VTCompressionSession`
- `VirtualDisplayController` — high-level facade combining display, recording,
  and streaming
- SwiftUI (`VirtualDisplayView`) and AppKit (`VirtualDisplayNSView`) view layers
- Preset configurations for common use cases including digital signage (portrait
  1080p / 4K) and landscape 1080p / 4K
- Concurrency-safe APIs using Swift 5.9 strict concurrency features
- Demo application and integration examples

## Gratitude

Thank you to Bastian Andelefski for open-sourcing DeskPad under a permissive
license. This project would not exist without that foundation.

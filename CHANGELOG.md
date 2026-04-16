# Changelog

All notable changes to VirtualDisplayKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

While on `0.x`, minor version bumps may include breaking API changes.

## [Unreleased]

## [0.1.0] - 2026-04-16

### Added

Initial public release. Forked from
[Stengo/DeskPad](https://github.com/Stengo/DeskPad) (MIT-licensed) and
extended into a Swift Package with the following capabilities:

- **`VirtualDisplay`** — create and manage virtual displays via the private
  `CGVirtualDisplay` API
- **`VirtualDisplayConfiguration`** — configurable resolution, refresh rate,
  HiDPI support, vendor/product identifiers, and preset configurations
  (`.preset1080p`, `.preset4K`, `.presetSignage`)
- **`DisplayStreamRenderer`** — `CGDisplayStream`-based frame delivery with
  both `IOSurface` and `CVPixelBuffer` output paths
- **`DisplayRecorder`** — record virtual display content to H.264/HEVC
  MP4/MOV via `AVAssetWriter`, with `.standard`, `.highQuality`, and
  `.hevcHighEfficiency` presets
- **`FrameOutputStream`** — emit encoded H.264/HEVC Annex-B or raw
  `CVPixelBuffer` frames for RTMP streaming, OBS integration, or custom
  pipelines, via `VTCompressionSession`; presets for `.rtmpStreaming`,
  `.highQuality`, `.realtime`
- **`VirtualDisplayController`** — high-level facade combining display,
  recording, and streaming
- **`VirtualDisplayView`** (SwiftUI) and **`VirtualDisplayNSView`** (AppKit)
  for preview integration
- **`MouseTracker`** — cursor position mapping between preview view and
  virtual display coordinate space
- **Demo app** at `Virtual Display.xcodeproj` demonstrating all features
- **Examples** for SwiftUI, AppKit, and digital signage use cases

[Unreleased]: https://github.com/Xocialize/VirtualDisplayKit/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Xocialize/VirtualDisplayKit/releases/tag/v0.1.0

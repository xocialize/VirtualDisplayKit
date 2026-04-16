//
//  VirtualDisplayKit.swift
//  VirtualDisplayKit
//
//  A modular framework for creating and managing virtual displays on macOS.
//

// Re-export Foundation types
@_exported import Foundation
@_exported import CoreGraphics
@_exported import AVFoundation

// All public types are automatically exported from their respective files:
// - VirtualDisplay (Core/VirtualDisplay.swift)
// - VirtualDisplayConfiguration, DisplayMode, StreamingBackend (Core/VirtualDisplayConfiguration.swift)
// - VirtualDisplayError, VirtualDisplayDelegate (Core/VirtualDisplay.swift)
// - VirtualDisplayController (VirtualDisplayController.swift)
// - VirtualDisplayView (Views/VirtualDisplayView.swift)
// - VirtualDisplayNSView (Views/VirtualDisplayNSView.swift)
// - DisplayStreamRenderer (Core/DisplayStreamRenderer.swift)
// - DisplayRecorder, RecordingConfiguration, DisplayRecorderError, DisplayRecorderDelegate (Core/DisplayRecorder.swift)
// - FrameOutputStream, StreamOutputConfiguration, StreamOutputFormat, FrameOutputStreamDelegate (Core/FrameOutputStream.swift)
// - NSScreen extensions (Extensions/NSScreen+Extensions.swift)

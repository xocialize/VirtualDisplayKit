//
//  VirtualDisplayConfiguration.swift
//  VirtualDisplayKit
//
//  Configuration options for creating virtual displays.
//

import Foundation
import CoreGraphics

/// Configuration for creating a virtual display
public struct VirtualDisplayConfiguration: Sendable {
    
    // MARK: - Display Properties
    
    /// Name shown in Display preferences
    public var name: String
    
    /// Maximum pixel width the display can support
    public var maxWidth: UInt32
    
    /// Maximum pixel height the display can support
    public var maxHeight: UInt32
    
    /// Physical size in millimeters (affects DPI calculations)
    public var physicalSizeMillimeters: CGSize
    
    /// Vendor ID for display identification
    public var vendorID: UInt32
    
    /// Product ID for display identification
    public var productID: UInt32
    
    /// Serial number for display identification
    public var serialNumber: UInt32
    
    /// Whether to enable HiDPI (Retina) modes
    public var hiDPIEnabled: Bool
    
    /// Refresh rate in Hz
    public var refreshRate: CGFloat
    
    /// Available display modes
    public var displayModes: [DisplayMode]
    
    // MARK: - Streaming Options
    
    /// Whether to show the cursor in the stream
    public var showCursor: Bool
    
    /// Preferred streaming backend
    public var streamingBackend: StreamingBackend
    
    // MARK: - Initialization
    
    /// Creates a new configuration with default values suitable for most use cases
    public init(
        name: String = "Virtual Display",
        maxWidth: UInt32 = 3840,
        maxHeight: UInt32 = 2160,
        physicalSizeMillimeters: CGSize = CGSize(width: 600, height: 340),
        vendorID: UInt32 = 0x3456,
        productID: UInt32 = 0x1234,
        serialNumber: UInt32 = 0x0001,
        hiDPIEnabled: Bool = true,
        refreshRate: CGFloat = 60,
        displayModes: [DisplayMode]? = nil,
        showCursor: Bool = true,
        streamingBackend: StreamingBackend = .automatic
    ) {
        self.name = name
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.physicalSizeMillimeters = physicalSizeMillimeters
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = serialNumber
        self.hiDPIEnabled = hiDPIEnabled
        self.refreshRate = refreshRate
        self.displayModes = displayModes ?? Self.defaultDisplayModes(refreshRate: refreshRate)
        self.showCursor = showCursor
        self.streamingBackend = streamingBackend
    }
    
    // MARK: - Presets
    
    /// Configuration preset for 1080p displays
    public static var preset1080p: VirtualDisplayConfiguration {
        VirtualDisplayConfiguration(
            name: "Virtual Display 1080p",
            maxWidth: 1920,
            maxHeight: 1080,
            displayModes: [
                DisplayMode(width: 1920, height: 1080, refreshRate: 60),
                DisplayMode(width: 1280, height: 720, refreshRate: 60),
            ]
        )
    }
    
    /// Configuration preset for 1080p portrait displays
    public static var preset1080pPortrait: VirtualDisplayConfiguration {
        VirtualDisplayConfiguration(
            name: "Virtual Display Portrait",
            maxWidth: 1080,
            maxHeight: 1920,
            displayModes: [
                DisplayMode(width: 1080, height: 1920, refreshRate: 60),
                DisplayMode(width: 720, height: 1280, refreshRate: 60),
            ]
        )
    }
    
    /// Configuration preset for 4K displays
    public static var preset4K: VirtualDisplayConfiguration {
        VirtualDisplayConfiguration(
            name: "Virtual Display 4K",
            maxWidth: 3840,
            maxHeight: 2160,
            displayModes: [
                DisplayMode(width: 3840, height: 2160, refreshRate: 60),
                DisplayMode(width: 2560, height: 1440, refreshRate: 60),
                DisplayMode(width: 1920, height: 1080, refreshRate: 60),
            ]
        )
    }
    
    /// Configuration preset for 4K portrait displays
    public static var preset4KPortrait: VirtualDisplayConfiguration {
        VirtualDisplayConfiguration(
            name: "Virtual Display 4K Portrait",
            maxWidth: 2160,
            maxHeight: 3840,
            displayModes: [
                DisplayMode(width: 2160, height: 3840, refreshRate: 60),
                DisplayMode(width: 1440, height: 2560, refreshRate: 60),
                DisplayMode(width: 1080, height: 1920, refreshRate: 60),
            ]
        )
    }
    
    // MARK: - Default Modes
    
    private static func defaultDisplayModes(refreshRate: CGFloat) -> [DisplayMode] {
        [
            // 16:9 aspect ratio
            DisplayMode(width: 3840, height: 2160, refreshRate: refreshRate),
            DisplayMode(width: 2560, height: 1440, refreshRate: refreshRate),
            DisplayMode(width: 1920, height: 1080, refreshRate: refreshRate),
            DisplayMode(width: 1600, height: 900, refreshRate: refreshRate),
            DisplayMode(width: 1366, height: 768, refreshRate: refreshRate),
            DisplayMode(width: 1280, height: 720, refreshRate: refreshRate),
            // 16:10 aspect ratio
            DisplayMode(width: 2560, height: 1600, refreshRate: refreshRate),
            DisplayMode(width: 1920, height: 1200, refreshRate: refreshRate),
            DisplayMode(width: 1680, height: 1050, refreshRate: refreshRate),
            DisplayMode(width: 1440, height: 900, refreshRate: refreshRate),
            DisplayMode(width: 1280, height: 800, refreshRate: refreshRate),
        ]
    }
}

// MARK: - Supporting Types

/// Represents a display mode (resolution + refresh rate)
public struct DisplayMode: Sendable, Hashable {
    public let width: Int
    public let height: Int
    public let refreshRate: CGFloat
    
    public init(width: Int, height: Int, refreshRate: CGFloat = 60) {
        self.width = width
        self.height = height
        self.refreshRate = refreshRate
    }
    
    public var size: CGSize {
        CGSize(width: width, height: height)
    }
    
    public var aspectRatio: CGFloat {
        guard height > 0 else { return 0 }
        return CGFloat(width) / CGFloat(height)
    }
}

/// Backend options for display streaming
public enum StreamingBackend: Sendable {
    /// Automatically select the best available backend
    case automatic
    
    /// Use ScreenCaptureKit (macOS 12.3+, recommended)
    case screenCaptureKit
    
    /// Use legacy CGDisplayStream (deprecated but wider compatibility)
    case cgDisplayStream
}

/// Display rotation options
public enum DisplayRotation: Int, Sendable, CaseIterable {
    /// No rotation (landscape)
    case none = 0
    
    /// 90 degrees clockwise (portrait, home button on right)
    case clockwise90 = 90
    
    /// 180 degrees (landscape, upside down)
    case upsideDown = 180
    
    /// 270 degrees clockwise / 90 degrees counter-clockwise (portrait, home button on left)
    case counterClockwise90 = 270
    
    /// Rotation angle in radians
    public var radians: CGFloat {
        CGFloat(rawValue) * .pi / 180.0
    }
    
    /// Rotation angle in degrees
    public var degrees: Int {
        rawValue
    }
    
    /// Whether this rotation results in a portrait orientation (width < height)
    public var isPortrait: Bool {
        self == .clockwise90 || self == .counterClockwise90
    }
    
    /// Display name for UI
    public var displayName: String {
        switch self {
        case .none: return "0°"
        case .clockwise90: return "90°"
        case .upsideDown: return "180°"
        case .counterClockwise90: return "270°"
        }
    }
}

//
//  NSScreen+Extensions.swift
//  VirtualDisplayKit
//
//  Extensions for NSScreen to support virtual display identification.
//

import AppKit

extension NSScreen {
    
    /// The CoreGraphics display ID for this screen
    public var displayID: CGDirectDisplayID {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            assertionFailure("Failed to get display ID from NSScreen")
            return 0
        }
        return CGDirectDisplayID(screenNumber.uint32Value)
    }
    
    /// Whether this screen is the main/primary display
    public var isMainDisplay: Bool {
        displayID == CGMainDisplayID()
    }
    
    /// The backing scale factor for HiDPI displays
    public var retinaScaleFactor: CGFloat {
        backingScaleFactor
    }
    
    /// Native resolution in pixels (accounting for scale factor)
    public var nativeResolution: CGSize {
        CGSize(
            width: frame.width * backingScaleFactor,
            height: frame.height * backingScaleFactor
        )
    }
    
    /// Returns the screen containing the specified display ID, if any
    public static func screen(withDisplayID displayID: CGDirectDisplayID) -> NSScreen? {
        screens.first { $0.displayID == displayID }
    }
}

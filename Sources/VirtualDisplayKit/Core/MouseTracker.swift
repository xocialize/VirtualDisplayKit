//
//  MouseTracker.swift
//  VirtualDisplayKit
//
//  Tracks mouse position relative to virtual displays and handles cursor movement.
//

import AppKit
import Combine

/// Tracks mouse position and handles cursor movement to/from virtual displays
@MainActor
public final class MouseTracker: ObservableObject {
    
    // MARK: - Published State
    
    /// Whether the mouse cursor is currently within the virtual display
    @Published public private(set) var isWithinVirtualDisplay = false
    
    /// Current mouse position in display coordinates (if within virtual display)
    @Published public private(set) var mousePosition: CGPoint?
    
    // MARK: - Private Properties
    
    // Using nonisolated(unsafe) to allow cleanup in deinit
    private nonisolated(unsafe) var timerSubscription: AnyCancellable?
    private var displayID: CGDirectDisplayID?
    private var trackingInterval: TimeInterval
    
    // MARK: - Initialization
    
    /// Creates a new mouse tracker
    /// - Parameter trackingInterval: How often to poll mouse position (default: 0.25 seconds)
    public init(trackingInterval: TimeInterval = 0.25) {
        self.trackingInterval = trackingInterval
    }
    
    deinit {
        timerSubscription?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Starts tracking mouse position relative to the specified display
    /// - Parameter displayID: The display to track
    public func startTracking(displayID: CGDirectDisplayID) {
        self.displayID = displayID
        
        // Stop any existing subscription
        stopTracking()
        
        // Start polling timer using Combine
        timerSubscription = Timer.publish(every: trackingInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMouseLocation()
            }
    }
    
    /// Stops tracking mouse position
    public func stopTracking() {
        timerSubscription?.cancel()
        timerSubscription = nil
        isWithinVirtualDisplay = false
        mousePosition = nil
    }
    
    /// Moves the cursor to the specified point on the virtual display
    /// - Parameter point: Target position in display coordinates
    public func moveCursor(to point: CGPoint) {
        guard let displayID = displayID else { return }
        CGDisplayMoveCursorToPoint(displayID, point)
    }
    
    /// Warps the cursor to the center of the virtual display
    public func moveCursorToCenter() {
        guard let displayID = displayID,
              let screen = NSScreen.screen(withDisplayID: displayID) else { return }
        
        let center = CGPoint(
            x: screen.frame.width / 2,
            y: screen.frame.height / 2
        )
        moveCursor(to: center)
    }
    
    // MARK: - Private Methods
    
    private func updateMouseLocation() {
        guard let displayID = displayID else {
            isWithinVirtualDisplay = false
            mousePosition = nil
            return
        }
        
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        
        // Find which screen contains the mouse
        let screenContainingMouse = screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        }
        
        // Check if it's the virtual display
        let isWithin = screenContainingMouse?.displayID == displayID
        isWithinVirtualDisplay = isWithin
        
        if isWithin, let screen = screenContainingMouse {
            // Calculate position relative to the virtual display
            let relativeX = mouseLocation.x - screen.frame.origin.x
            let relativeY = mouseLocation.y - screen.frame.origin.y
            // Flip Y for top-left origin
            mousePosition = CGPoint(x: relativeX, y: screen.frame.height - relativeY)
        } else {
            mousePosition = nil
        }
    }
}

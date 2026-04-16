//
//  VirtualDisplay.swift
//  VirtualDisplayKit
//
//  Main class for creating and managing virtual displays.
//

import Cocoa
import Combine
import CVirtualDisplayPrivate

/// Delegate protocol for receiving virtual display events
@MainActor
public protocol VirtualDisplayDelegate: AnyObject {
    /// Called when the virtual display is ready to use
    func virtualDisplayDidBecomeReady(_ display: VirtualDisplay)
    
    /// Called when the display resolution changes
    func virtualDisplay(_ display: VirtualDisplay, didChangeResolution resolution: CGSize, scaleFactor: CGFloat)
    
    /// Called when the cursor enters or exits the virtual display
    func virtualDisplay(_ display: VirtualDisplay, cursorDidEnter isInside: Bool)
    
    /// Called when an error occurs
    func virtualDisplay(_ display: VirtualDisplay, didEncounterError error: VirtualDisplayError)
}

/// Default implementations for optional delegate methods
public extension VirtualDisplayDelegate {
    func virtualDisplayDidBecomeReady(_ display: VirtualDisplay) {}
    func virtualDisplay(_ display: VirtualDisplay, didChangeResolution resolution: CGSize, scaleFactor: CGFloat) {}
    func virtualDisplay(_ display: VirtualDisplay, cursorDidEnter isInside: Bool) {}
    func virtualDisplay(_ display: VirtualDisplay, didEncounterError error: VirtualDisplayError) {}
}

/// Errors that can occur during virtual display operations
public enum VirtualDisplayError: Error, LocalizedError {
    case failedToCreate
    case displayNotFound
    case streamingFailed(underlying: Error?)
    case permissionDenied
    case unsupportedConfiguration
    
    public var errorDescription: String? {
        switch self {
        case .failedToCreate:
            return "Failed to create virtual display"
        case .displayNotFound:
            return "Virtual display not found in system displays"
        case .streamingFailed(let underlying):
            if let error = underlying {
                return "Display streaming failed: \(error.localizedDescription)"
            }
            return "Display streaming failed"
        case .permissionDenied:
            return "Screen recording permission denied"
        case .unsupportedConfiguration:
            return "Display configuration not supported"
        }
    }
}

/// Main class for managing a virtual display
@MainActor
public final class VirtualDisplay: ObservableObject {
    
    // MARK: - Published State
    
    /// The CoreGraphics display ID of the virtual display
    @Published public private(set) var displayID: CGDirectDisplayID?
    
    /// Current resolution of the display
    @Published public private(set) var resolution: CGSize = .zero
    
    /// Current scale factor (1.0 for standard, 2.0 for Retina)
    @Published public private(set) var scaleFactor: CGFloat = 1.0
    
    /// Whether the virtual display is ready for use
    @Published public private(set) var isReady = false
    
    /// Whether the cursor is currently within the virtual display
    @Published public private(set) var isCursorInside = false
    
    // MARK: - Configuration
    
    /// The configuration used to create this display
    public let configuration: VirtualDisplayConfiguration
    
    /// Delegate for receiving display events
    public weak var delegate: VirtualDisplayDelegate?
    
    // MARK: - Private Properties
    
    private var virtualDisplay: CGVirtualDisplay?
    // Using nonisolated(unsafe) to allow cleanup in deinit
    private nonisolated(unsafe) var screenChangeSubscription: AnyCancellable?
    private nonisolated(unsafe) var cursorTrackingSubscription: AnyCancellable?
    private nonisolated(unsafe) var retrySubscription: AnyCancellable?
    private var retryCount = 0
    
    private static let maxRetries = 50
    private static let retryInterval: TimeInterval = 0.1
    private static let cursorTrackingInterval: TimeInterval = 0.25
    
    // MARK: - Initialization
    
    /// Creates a new virtual display manager with the specified configuration
    /// - Parameter configuration: The display configuration to use
    public init(configuration: VirtualDisplayConfiguration = VirtualDisplayConfiguration()) {
        self.configuration = configuration
    }
    
    deinit {
        // Clean up subscriptions
        screenChangeSubscription?.cancel()
        cursorTrackingSubscription?.cancel()
        retrySubscription?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Creates and activates the virtual display
    /// Call this method to start the virtual display. The display will be ready
    /// when `isReady` becomes true or when `virtualDisplayDidBecomeReady` is called.
    public func start() {
        guard virtualDisplay == nil else { return }
        
        // Create descriptor
        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(DispatchQueue.main)
        descriptor.name = configuration.name
        descriptor.maxPixelsWide = configuration.maxWidth
        descriptor.maxPixelsHigh = configuration.maxHeight
        descriptor.sizeInMillimeters = configuration.physicalSizeMillimeters
        descriptor.vendorID = configuration.vendorID
        descriptor.productID = configuration.productID
        descriptor.serialNum = configuration.serialNumber
        
        print("[VirtualDisplay] Creating display with config:")
        print("  - Name: \(configuration.name)")
        print("  - Max size: \(configuration.maxWidth)x\(configuration.maxHeight)")
        print("  - Modes: \(configuration.displayModes.map { "\($0.width)x\($0.height)@\($0.refreshRate)Hz" })")
        
        // Create the virtual display
        let display = CGVirtualDisplay(descriptor: descriptor)
        virtualDisplay = display
        displayID = display.displayID
        
        print("[VirtualDisplay] Created with displayID: \(display.displayID)")
        print("[VirtualDisplay] Available screens: \(NSScreen.screens.map { "\($0.localizedName): \($0.displayID)" })")
        
        // Configure settings
        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = configuration.hiDPIEnabled ? 1 : 0
        settings.modes = configuration.displayModes.map { mode in
            CGVirtualDisplayMode(
                width: UInt(mode.width),
                height: UInt(mode.height),
                refreshRate: mode.refreshRate
            )
        }
        let success = display.apply(settings)
        print("[VirtualDisplay] Applied settings: \(success)")
        print("[VirtualDisplay] Display modes after apply: \(display.modes ?? [])")
        print("[VirtualDisplay] Display hiDPI: \(display.hiDPI)")
        
        // Observe screen parameter changes
        screenChangeSubscription = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification, object: NSApplication.shared)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateScreenConfiguration()
            }
        
        // Start cursor tracking
        startCursorTracking()
        
        // Start retry loop to find the display
        retryCount = 0
        startRetryLoop()
    }
    
    /// Stops and destroys the virtual display
    public func stop() {
        screenChangeSubscription?.cancel()
        screenChangeSubscription = nil
        cursorTrackingSubscription?.cancel()
        cursorTrackingSubscription = nil
        retrySubscription?.cancel()
        retrySubscription = nil
        
        virtualDisplay = nil
        displayID = nil
        resolution = .zero
        scaleFactor = 1.0
        isReady = false
        isCursorInside = false
    }
    
    /// Moves the system cursor to a point on the virtual display
    /// - Parameter point: The point in display coordinates
    public func moveCursor(to point: CGPoint) {
        guard let displayID = displayID else { return }
        CGDisplayMoveCursorToPoint(displayID, point)
    }
    
    /// Returns the NSScreen object for this virtual display, if available
    public var screen: NSScreen? {
        guard let displayID = displayID else { return nil }
        return NSScreen.screen(withDisplayID: displayID)
    }
    
    // MARK: - Private Methods
    
    private func startRetryLoop() {
        retrySubscription = Timer.publish(every: Self.retryInterval, on: .main, in: .common)
            .autoconnect()
            .prefix(Self.maxRetries)
            .sink { [weak self] _ in
                self?.updateScreenConfiguration()
            }
    }
    
    private func startCursorTracking() {
        cursorTrackingSubscription = Timer.publish(every: Self.cursorTrackingInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateCursorLocation()
            }
    }
    
    private func updateScreenConfiguration() {
        guard let displayID = displayID else { return }
        
        guard let screen = NSScreen.screen(withDisplayID: displayID) else {
            retryCount += 1
            if retryCount % 10 == 0 {
                print("[VirtualDisplay] Retry \(retryCount)/\(Self.maxRetries) - Looking for displayID: \(displayID)")
                print("[VirtualDisplay] Available screens: \(NSScreen.screens.map { "\($0.localizedName): \($0.displayID)" })")
            }
            if retryCount >= Self.maxRetries {
                print("[VirtualDisplay] ERROR: Display not found after \(Self.maxRetries) retries")
                delegate?.virtualDisplay(self, didEncounterError: .displayNotFound)
            }
            return
        }
        
        print("[VirtualDisplay] Found screen: \(screen.localizedName) at \(screen.frame)")
        
        // Found the screen - stop retry loop
        retrySubscription?.cancel()
        retrySubscription = nil
        
        let newResolution = screen.frame.size
        let newScaleFactor = screen.backingScaleFactor
        
        let resolutionChanged = resolution != newResolution || scaleFactor != newScaleFactor
        let wasReady = isReady
        
        resolution = newResolution
        scaleFactor = newScaleFactor
        isReady = true
        
        if !wasReady {
            delegate?.virtualDisplayDidBecomeReady(self)
        } else if resolutionChanged {
            delegate?.virtualDisplay(self, didChangeResolution: newResolution, scaleFactor: newScaleFactor)
        }
    }
    
    private func updateCursorLocation() {
        guard let displayID = displayID else {
            if isCursorInside {
                isCursorInside = false
                delegate?.virtualDisplay(self, cursorDidEnter: false)
            }
            return
        }
        
        let mouseLocation = NSEvent.mouseLocation
        let screenContainingMouse = NSScreen.screens.first { screen in
            NSMouseInRect(mouseLocation, screen.frame, false)
        }
        
        let newCursorInside = screenContainingMouse?.displayID == displayID
        
        if newCursorInside != isCursorInside {
            isCursorInside = newCursorInside
            delegate?.virtualDisplay(self, cursorDidEnter: newCursorInside)
        }
    }
}

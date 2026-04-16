//
//  VirtualDisplayNSView.swift
//  VirtualDisplayKit
//
//  AppKit view for displaying a virtual display stream.
//

import Cocoa
import Combine

/// An AppKit view that displays the contents of a virtual display
@MainActor
public final class VirtualDisplayNSView: NSView {
    
    // MARK: - Properties
    
    private var virtualDisplay: VirtualDisplay?
    private var renderer: DisplayStreamRenderer?
    private var cancellables = Set<AnyCancellable>()
    
    /// Whether to highlight the view when the cursor is in the virtual display
    public var highlightWhenCursorInside: Bool = true {
        didSet { updateHighlight() }
    }
    
    /// Called when the view is tapped, with the display coordinates
    public var onTap: ((CGPoint) -> Void)?
    
    /// Called when the view is double-tapped, with the display coordinates
    public var onDoubleTap: ((CGPoint) -> Void)?
    
    // MARK: - Initialization
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        
        // Add border
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        
        // Add shadow
        shadow = NSShadow()
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.2
        layer?.shadowOffset = CGSize(width: 0, height: -2)
        layer?.shadowRadius = 4
        
        // Add click gestures
        let singleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleSingleClick(_:)))
        singleClickGesture.numberOfClicksRequired = 1
        addGestureRecognizer(singleClickGesture)
        
        let doubleClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        addGestureRecognizer(doubleClickGesture)
        
        // Make single click wait for double click to fail
        singleClickGesture.shouldRequireFailure(of: doubleClickGesture)
    }
    
    // MARK: - Public Methods
    
    /// Attaches a virtual display to this view
    /// - Parameter virtualDisplay: The virtual display to display
    public func attach(_ virtualDisplay: VirtualDisplay) {
        // Clean up old subscription
        cancellables.removeAll()
        self.virtualDisplay = virtualDisplay
        
        // Create renderer if needed
        if renderer == nil {
            let newRenderer = DisplayStreamRenderer(
                frame: bounds,
                backend: virtualDisplay.configuration.streamingBackend,
                showCursor: virtualDisplay.configuration.showCursor
            )
            newRenderer.translatesAutoresizingMaskIntoConstraints = false
            addSubview(newRenderer)
            
            NSLayoutConstraint.activate([
                newRenderer.leadingAnchor.constraint(equalTo: leadingAnchor),
                newRenderer.trailingAnchor.constraint(equalTo: trailingAnchor),
                newRenderer.topAnchor.constraint(equalTo: topAnchor),
                newRenderer.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            
            renderer = newRenderer
        }
        
        // Subscribe to display state changes
        virtualDisplay.$isReady
            .combineLatest(virtualDisplay.$displayID, virtualDisplay.$resolution, virtualDisplay.$scaleFactor)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReady, displayID, resolution, scaleFactor in
                guard isReady, let displayID = displayID, resolution != .zero else { return }
                self?.renderer?.configure(displayID: displayID, resolution: resolution, scaleFactor: scaleFactor)
            }
            .store(in: &cancellables)
        
        // Subscribe to cursor state
        virtualDisplay.$isCursorInside
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateHighlight()
            }
            .store(in: &cancellables)
        
        // If already ready, configure immediately
        if virtualDisplay.isReady,
           let displayID = virtualDisplay.displayID,
           virtualDisplay.resolution != .zero {
            renderer?.configure(
                displayID: displayID,
                resolution: virtualDisplay.resolution,
                scaleFactor: virtualDisplay.scaleFactor
            )
        }
    }
    
    /// Detaches the current virtual display
    public func detach() {
        cancellables.removeAll()
        renderer?.stopStream()
        virtualDisplay = nil
    }
    
    // MARK: - Private Methods
    
    private func updateHighlight() {
        guard highlightWhenCursorInside else {
            layer?.borderWidth = 1
            layer?.borderColor = NSColor.separatorColor.cgColor
            return
        }
        
        let isInside = virtualDisplay?.isCursorInside ?? false
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            layer?.borderWidth = isInside ? 3 : 1
            layer?.borderColor = isInside ? NSColor.controlAccentColor.cgColor : NSColor.separatorColor.cgColor
        }
    }
    
    @objc private func handleSingleClick(_ gesture: NSClickGestureRecognizer) {
        guard let renderer = renderer else { return }
        let viewPoint = gesture.location(in: renderer)
        
        if let displayPoint = renderer.convertToDisplayCoordinates(viewPoint) {
            onTap?(displayPoint)
        }
    }
    
    @objc private func handleDoubleClick(_ gesture: NSClickGestureRecognizer) {
        guard let renderer = renderer else { return }
        let viewPoint = gesture.location(in: renderer)
        
        if let displayPoint = renderer.convertToDisplayCoordinates(viewPoint) {
            onDoubleTap?(displayPoint)
        }
    }
    
    // MARK: - Layout
    
    public override var intrinsicContentSize: NSSize {
        guard let resolution = virtualDisplay?.resolution, resolution != .zero else {
            return NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
        }
        return NSSizeFromCGSize(resolution)
    }
}

//
//  VirtualDisplayController.swift
//  VirtualDisplayKit
//
//  High-level controller for managing virtual displays with recording and streaming.
//

import Cocoa
import Combine

/// A high-level controller that manages a virtual display with recording and streaming support
///
/// Use this class when you want simple, all-in-one virtual display functionality.
///
/// Example usage:
/// ```swift
/// let controller = VirtualDisplayController()
///
/// // Create a window that shows the virtual display
/// let window = controller.createPreviewWindow()
/// window.makeKeyAndOrderFront(nil)
///
/// // Start the virtual display
/// controller.start()
///
/// // Record the display
/// try controller.startRecording(to: recordingURL)
///
/// // Or stream the display
/// controller.startStreaming { data, time, isKeyFrame in
///     // Send to your streaming server
/// }
/// ```
@MainActor
public final class VirtualDisplayController: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The underlying virtual display
    @Published public private(set) var virtualDisplay: VirtualDisplay
    
    /// Whether the virtual display is ready
    public var isReady: Bool { virtualDisplay.isReady }
    
    /// Current display resolution
    public var resolution: CGSize { virtualDisplay.resolution }
    
    /// Current display ID
    public var displayID: CGDirectDisplayID? { virtualDisplay.displayID }
    
    /// Whether recording is active
    @Published public private(set) var isRecording = false
    
    /// Current recording duration
    @Published public private(set) var recordingDuration: TimeInterval = 0
    
    /// Whether streaming is active
    @Published public private(set) var isStreaming = false
    
    /// Current streaming frame rate
    @Published public private(set) var streamingFrameRate: Double = 0
    
    // MARK: - Recording & Streaming
    
    private var recorder: DisplayRecorder?
    private var frameOutputStream: FrameOutputStream?
    private var displayView: VirtualDisplayNSView?
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var previewWindow: NSWindow?
    private var captureRenderer: DisplayStreamRenderer?  // Keep reference for frame capture
    
    // MARK: - Initialization
    
    /// Creates a new controller with the specified configuration
    /// - Parameter configuration: Display configuration (defaults to preset1080p)
    public init(configuration: VirtualDisplayConfiguration = .preset1080p) {
        self.virtualDisplay = VirtualDisplay(configuration: configuration)
    }
    
    /// Creates a new controller with a preset configuration
    /// - Parameter preset: The preset to use
    public convenience init(preset: ConfigurationPreset) {
        switch preset {
        case .standard1080p:
            self.init(configuration: .preset1080p)
        case .portrait1080p:
            self.init(configuration: .preset1080pPortrait)
        case .high4K:
            self.init(configuration: .preset4K)
        case .portrait4K:
            self.init(configuration: .preset4KPortrait)
        }
    }
    
    // MARK: - Lifecycle
    
    /// Starts the virtual display
    public func start() {
        virtualDisplay.start()
    }
    
    /// Stops the virtual display and any active recording/streaming
    public func stop() {
        Task {
            if isRecording {
                try? await stopRecording()
            }
        }
        
        if isStreaming {
            stopStreaming()
        }
        
        captureRenderer?.stopStream()
        captureRenderer = nil
        
        virtualDisplay.stop()
        previewWindow?.close()
        previewWindow = nil
    }
    
    // MARK: - Recording
    
    /// Starts recording the virtual display to a file
    /// - Parameters:
    ///   - url: Output file URL
    ///   - configuration: Recording configuration (defaults to standard)
    public func startRecording(
        to url: URL,
        configuration: RecordingConfiguration = .standard
    ) throws {
        guard !isRecording else { return }
        guard virtualDisplay.isReady else {
            throw DisplayRecorderError.notConfigured
        }
        
        let recorder = DisplayRecorder(configuration: configuration)
        recorder.configure(
            displaySize: virtualDisplay.resolution,
            scaleFactor: virtualDisplay.scaleFactor
        )
        
        // Subscribe to duration updates
        recorder.$duration
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordingDuration)
        
        try recorder.startRecording(to: url)
        
        self.recorder = recorder
        isRecording = true
        
        // Connect frame callback
        setupFrameCallback()
    }
    
    /// Stops the current recording
    @discardableResult
    public func stopRecording() async throws -> URL? {
        guard isRecording, let recorder = recorder else {
            return nil
        }
        
        try await recorder.stopRecording()
        let url = recorder.outputURL
        
        self.recorder = nil
        isRecording = false
        recordingDuration = 0
        
        // Clean up capture renderer if not streaming
        if !isStreaming {
            captureRenderer?.stopStream()
            captureRenderer = nil
        }
        
        return url
    }
    
    // MARK: - Streaming
    
    /// Starts streaming encoded frames
    /// - Parameters:
    ///   - configuration: Stream output configuration
    ///   - onFrame: Callback for each encoded frame
    public func startStreaming(
        configuration: StreamOutputConfiguration = .rtmpStreaming,
        onFrame: @escaping (_ data: Data, _ presentationTime: CMTime, _ isKeyFrame: Bool) -> Void
    ) throws {
        guard !isStreaming else { return }
        guard virtualDisplay.isReady else {
            throw DisplayRecorderError.notConfigured
        }
        
        let stream = FrameOutputStream(configuration: configuration)
        stream.configure(
            displaySize: virtualDisplay.resolution,
            scaleFactor: virtualDisplay.scaleFactor
        )
        
        stream.onEncodedFrame = onFrame
        
        // Subscribe to frame rate updates
        stream.$currentFrameRate
            .receive(on: DispatchQueue.main)
            .assign(to: &$streamingFrameRate)
        
        try stream.start()
        
        self.frameOutputStream = stream
        isStreaming = true
        
        // Connect frame callback
        setupFrameCallback()
    }
    
    /// Stops streaming
    public func stopStreaming() {
        guard isStreaming else { return }
        
        frameOutputStream?.stop()
        frameOutputStream = nil
        isStreaming = false
        streamingFrameRate = 0
        
        // Clean up capture renderer if not recording
        if !isRecording {
            captureRenderer?.stopStream()
            captureRenderer = nil
        }
    }
    
    // MARK: - Preview Window
    
    /// Creates a preview window that shows the virtual display contents
    /// - Parameters:
    ///   - title: Window title
    ///   - initialSize: Initial window size (defaults to 1280x720)
    ///   - minSize: Minimum window size
    /// - Returns: A configured NSWindow
    public func createPreviewWindow(
        title: String = "Virtual Display",
        initialSize: CGSize = CGSize(width: 1280, height: 720),
        minSize: CGSize = CGSize(width: 400, height: 300)
    ) -> NSWindow {
        // Create the view
        let view = VirtualDisplayNSView()
        view.attach(virtualDisplay)
        view.onTap = { [weak self] point in
            self?.virtualDisplay.moveCursor(to: point)
        }
        
        displayView = view
        
        // Create and configure window
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = title
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .white
        window.contentMinSize = minSize
        window.contentView = view
        window.center()
        
        // Update aspect ratio when display resolution changes
        virtualDisplay.$resolution
            .receive(on: DispatchQueue.main)
            .sink { [weak window] resolution in
                guard resolution != .zero else { return }
                window?.contentAspectRatio = resolution
            }
            .store(in: &cancellables)
        
        // Highlight window when cursor is in virtual display
        virtualDisplay.$isCursorInside
            .receive(on: DispatchQueue.main)
            .sink { [weak window] isInside in
                if isInside {
                    window?.orderFrontRegardless()
                }
            }
            .store(in: &cancellables)
        
        previewWindow = window
        return window
    }
    
    /// Creates a SwiftUI view for embedding in SwiftUI hierarchies
    /// - Returns: A VirtualDisplayView configured for this controller
    public func makeView() -> VirtualDisplayView {
        VirtualDisplayView(virtualDisplay: virtualDisplay) { [weak self] point in
            self?.virtualDisplay.moveCursor(to: point)
        }
    }
    
    // MARK: - Cursor Control
    
    /// Moves the cursor to a specific point on the virtual display
    /// - Parameter point: The point in display coordinates
    public func moveCursor(to point: CGPoint) {
        virtualDisplay.moveCursor(to: point)
    }
    
    // MARK: - Private Methods
    
    private func setupFrameCallback() {
        guard isRecording || isStreaming else { return }
        guard let displayID = virtualDisplay.displayID else { return }
        
        // Create a dedicated renderer for capturing frames
        let renderer = DisplayStreamRenderer(backend: .cgDisplayStream, showCursor: true)
        renderer.configure(
            displayID: displayID,
            resolution: virtualDisplay.resolution,
            scaleFactor: virtualDisplay.scaleFactor
        )
        
        renderer.onFrameAvailable = { [weak self] surface in
            guard let self = self else { return }
            
            // Send to recorder
            if self.isRecording {
                self.recorder?.appendFrame(from: surface)
            }
            
            // Send to stream
            if self.isStreaming {
                self.frameOutputStream?.processFrame(from: surface)
            }
        }
        
        // Store reference to keep it alive
        self.captureRenderer = renderer
    }
}

// MARK: - Configuration Presets

public extension VirtualDisplayController {
    /// Preset configurations for common use cases
    enum ConfigurationPreset {
        /// Standard 1080p display (1920x1080) - Landscape
        case standard1080p
        
        /// Standard 1080p display (1080x1920) - Portrait
        case portrait1080p
        
        /// High-resolution 4K display (3840x2160) - Landscape
        case high4K
        
        /// High-resolution 4K display (2160x3840) - Portrait
        case portrait4K
    }
}

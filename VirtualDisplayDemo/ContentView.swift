//
//  ContentView.swift
//  VirtualDisplayDemo
//
//  Main content view for the demo application.
//

import SwiftUI
import VirtualDisplayKit
import Combine
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        HSplitView {
            // Left panel - Display preview
            displayPanel
                .frame(minWidth: 500)
            
            // Right panel - Controls
            controlPanel
                .frame(width: 320)
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Display Panel
    
    private var displayPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "display")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("Virtual Display")
                    .font(.title2.bold())
                
                Spacer()
                
                statusIndicator
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Display content
            ZStack {
                if viewModel.isDisplayActive {
                    if viewModel.isDisplayReady {
                        VirtualDisplayView(
                            virtualDisplay: viewModel.controller.virtualDisplay,
                            highlightWhenCursorInside: true
                        ) { point in
                            viewModel.controller.moveCursor(to: point)
                        }
                        .padding()
                    } else {
                        // Waiting for display to be ready
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Waiting for virtual display...")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    placeholderView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.05))
            
            Divider()
            
            // Info bar
            infoBar
        }
    }
    
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.secondary.opacity(0.1)))
    }
    
    private var statusColor: Color {
        if !viewModel.isDisplayActive {
            return .gray
        } else if viewModel.isDisplayReady {
            return .green
        } else {
            return .orange
        }
    }
    
    private var statusText: String {
        if !viewModel.isDisplayActive {
            return "Inactive"
        } else if viewModel.isDisplayReady {
            return "Active"
        } else {
            return "Starting..."
        }
    }
    
    private var placeholderView: some View {
        VStack(spacing: 20) {
            Image(systemName: "display.trianglebadge.exclamationmark")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Virtual Display")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Click \"Start Display\" to create a virtual display")
                .font(.callout)
                .foregroundColor(.secondary.opacity(0.8))
            
            Button("Start Display") {
                viewModel.toggleDisplay()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
    
    private var infoBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                infoItem(icon: "rectangle.dashed", title: "Resolution", value: viewModel.resolutionText)
                
                Divider().frame(height: 20)
                
                infoItem(icon: "scalemass", title: "Scale", value: viewModel.scaleText)
                
                Divider().frame(height: 20)
                
                infoItem(icon: "rectangle.portrait.arrowtriangle.2.outward", title: "Orientation", value: viewModel.orientationText)
                
                Divider().frame(height: 20)
                
                infoItem(icon: "cursorarrow", title: "Cursor Inside", value: viewModel.cursorInsideText)
                
                Spacer()
                
                if viewModel.isRecording {
                    recordingIndicator
                }
                
                if viewModel.isStreaming {
                    streamingIndicator
                }
            }
            
            if viewModel.isDisplayActive {
                HStack(spacing: 4) {
                    Image(systemName: "keyboard")
                        .font(.caption2)
                    Text("Press")
                    Text("⌃⌥⌘ Space")
                        .fontWeight(.medium)
                    Text("to return cursor to primary screen")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private func infoItem(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(.caption, design: .monospaced))
            }
        }
    }
    
    private var recordingIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .opacity(viewModel.recordingPulse ? 1 : 0.5)
                .animation(.easeInOut(duration: 0.5).repeatForever(), value: viewModel.recordingPulse)
            
            Text("REC")
                .font(.caption.bold())
                .foregroundColor(.red)
            
            Text(viewModel.recordingDurationText)
                .font(.system(.caption, design: .monospaced))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.red.opacity(0.1)))
    }
    
    private var streamingIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundColor(.green)
                .font(.caption)
            
            Text("LIVE")
                .font(.caption.bold())
                .foregroundColor(.green)
            
            Text("\(Int(viewModel.streamingFrameRate)) fps")
                .font(.system(.caption, design: .monospaced))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.green.opacity(0.1)))
    }
    
    // MARK: - Control Panel
    
    private var controlPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Display Controls
                controlSection(title: "Display", icon: "display") {
                    displayControls
                }
                
                Divider()
                
                // Recording Controls
                controlSection(title: "Recording", icon: "record.circle") {
                    recordingControls
                }
                
                Divider()
                
                // Streaming Controls
                controlSection(title: "Streaming", icon: "antenna.radiowaves.left.and.right") {
                    streamingControls
                }
                
                Spacer()
            }
            .padding()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    private func controlSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }
            
            content()
        }
    }
    
    private var displayControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preset")
                    .font(.subheadline)
                Spacer()
            }
            
            // Landscape presets
            HStack {
                Text("Landscape")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)
                
                HStack(spacing: 6) {
                    presetButton("1080p", preset: .standard1080p)
                    presetButton("4K", preset: .high4K)
                }
            }
            .disabled(viewModel.isDisplayActive)
            
            // Portrait presets
            HStack {
                Text("Portrait")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .leading)
                
                HStack(spacing: 6) {
                    presetButton("1080p", preset: .portrait1080p)
                    presetButton("4K", preset: .portrait4K)
                }
            }
            .disabled(viewModel.isDisplayActive)
            
            Button(action: viewModel.toggleDisplay) {
                HStack {
                    Image(systemName: viewModel.isDisplayActive ? "stop.fill" : "play.fill")
                    Text(viewModel.isDisplayActive ? "Stop Display" : "Start Display")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isDisplayActive ? .red : .green)
            .controlSize(.large)
        }
    }
    
    private func presetButton(_ title: String, preset: VirtualDisplayController.ConfigurationPreset) -> some View {
        Button(title) {
            Task { @MainActor in
                viewModel.selectedPreset = preset
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(viewModel.selectedPreset == preset ? .accentColor : .secondary)
    }
    
    private var recordingControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quality")
                    .font(.subheadline)
                Spacer()
            }
            
            HStack(spacing: 8) {
                qualityButton("Standard", quality: .standard)
                qualityButton("High", quality: .high)
                qualityButton("HEVC", quality: .hevc)
            }
            .disabled(viewModel.isRecording)
            
            Button(action: viewModel.toggleRecording) {
                HStack {
                    Image(systemName: viewModel.isRecording ? "stop.circle.fill" : "record.circle")
                    Text(viewModel.isRecording ? "Stop Recording" : "Start Recording")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isRecording ? .red : .orange)
            .controlSize(.large)
            .disabled(!viewModel.isDisplayReady)
            
            if let lastRecordingURL = viewModel.lastRecordingURL {
                HStack {
                    Image(systemName: "film")
                        .foregroundColor(.secondary)
                    
                    Text(lastRecordingURL.lastPathComponent)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Button("Reveal") {
                        NSWorkspace.shared.activateFileViewerSelecting([lastRecordingURL])
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))
            }
        }
    }
    
    private func qualityButton(_ title: String, quality: RecordingQuality) -> some View {
        Button(title) {
            Task { @MainActor in
                viewModel.recordingQuality = quality
            }
        }
        .buttonStyle(.bordered)
        .tint(viewModel.recordingQuality == quality ? .accentColor : .secondary)
    }
    
    private var streamingControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Format")
                    .font(.subheadline)
                Spacer()
            }
            
            HStack(spacing: 8) {
                formatButton("H.264", format: .h264)
                formatButton("HEVC", format: .hevc)
                formatButton("Raw", format: .raw)
            }
            .disabled(viewModel.isStreaming)
            
            Button(action: viewModel.toggleStreaming) {
                HStack {
                    Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "dot.radiowaves.left.and.right")
                    Text(viewModel.isStreaming ? "Stop Streaming" : "Start Streaming")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isStreaming ? .red : .purple)
            .controlSize(.large)
            .disabled(!viewModel.isDisplayReady)
            
            if viewModel.isStreaming {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Frames:")
                        Spacer()
                        Text("\(viewModel.streamingFrameCount)")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Data:")
                        Spacer()
                        Text(viewModel.streamingDataText)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))
            }
            
            Text("Streaming outputs encoded frames for integration with RTMP servers, OBS, or custom streaming solutions.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func formatButton(_ title: String, format: StreamingFormat) -> some View {
        Button(title) {
            Task { @MainActor in
                viewModel.streamingFormat = format
            }
        }
        .buttonStyle(.bordered)
        .tint(viewModel.streamingFormat == format ? .accentColor : .secondary)
    }
}

// MARK: - View Model

@MainActor
class ContentViewModel: ObservableObject {
    // Display state
    @Published var isDisplayActive = false
    @Published var isDisplayReady = false
    @Published var selectedPreset: VirtualDisplayController.ConfigurationPreset = .standard1080p
    @Published var displayResolution: CGSize = .zero
    @Published var displayScaleFactor: CGFloat = 1.0
    @Published var isCursorInside = false
    
    // Recording state
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var recordingQuality: RecordingQuality = .standard
    @Published var recordingPulse = false
    @Published var lastRecordingURL: URL?
    
    // Streaming state
    @Published var isStreaming = false
    @Published var streamingFrameRate: Double = 0
    @Published var streamingFormat: StreamingFormat = .h264
    @Published var streamingFrameCount: Int64 = 0
    @Published var streamingBytesOutput: Int64 = 0
    
    private(set) var controller: VirtualDisplayController!
    private var cancellables = Set<AnyCancellable>()
    private nonisolated(unsafe) var globalHotkeyMonitor: Any?
    private nonisolated(unsafe) var localHotkeyMonitor: Any?
    
    init() {
        setupController()
        setupGlobalHotkey()
    }
    
    deinit {
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func setupGlobalHotkey() {
        // Handler for the hotkey
        let hotkeyHandler: (NSEvent) -> Void = { [weak self] event in
            // Check for Ctrl + Cmd + Option + Space
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let isCtrlCmdOption = flags.contains([.control, .command, .option]) && !flags.contains(.shift)
            let isSpace = event.keyCode == 49 // Space key
            
            if isCtrlCmdOption && isSpace {
                print("[Hotkey] ⌃⌥⌘Space detected!")
                Task { @MainActor in
                    self?.returnCursorToPrimaryScreen()
                }
            }
        }
        
        // Global monitor for when other apps are focused (requires Accessibility permission)
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: hotkeyHandler)
        
        // Local monitor for when this app is focused
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            hotkeyHandler(event)
            return event
        }
        
        print("[Hotkey] Global hotkey monitor set up. Press ⌃⌥⌘Space to return cursor to primary screen.")
        print("[Hotkey] Note: Global monitoring requires Accessibility permission in System Settings.")
    }
    
    func returnCursorToPrimaryScreen() {
        guard let primaryScreen = NSScreen.screens.first else {
            print("[Hotkey] No primary screen found")
            return
        }
        
        // Get the frame of the primary screen
        let frame = primaryScreen.frame
        print("[Hotkey] Primary screen frame: \(frame)")
        
        // For CGWarpMouseCursorPosition, coordinates are in global display coordinates
        // The primary display's origin is at (0,0) in the top-left
        // We want the center of the primary display
        let centerX = frame.origin.x + frame.width / 2
        
        // NSScreen uses bottom-left origin, CGWarpMouseCursorPosition uses top-left
        // For the primary screen (which contains the menu bar), we need to convert
        let mainScreenHeight = NSScreen.screens.first?.frame.height ?? frame.height
        let centerY = mainScreenHeight - (frame.origin.y + frame.height / 2)
        
        let centerPoint = CGPoint(x: centerX, y: centerY)
        print("[Hotkey] Moving cursor to: \(centerPoint)")
        
        let result = CGWarpMouseCursorPosition(centerPoint)
        print("[Hotkey] CGWarpMouseCursorPosition result: \(result)")
        
        // Also associate the mouse with the point to avoid "jumping back" behavior
        CGAssociateMouseAndMouseCursorPosition(1)
    }
    
    private func setupController() {
        controller = VirtualDisplayController(preset: selectedPreset)
        observeController()
    }
    
    private func observeController() {
        cancellables.removeAll()
        
        // Observe virtual display state - use sink to avoid publishing during view updates
        controller.virtualDisplay.$isReady
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.isDisplayReady = value
            }
            .store(in: &cancellables)
        
        controller.virtualDisplay.$resolution
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.displayResolution = value
            }
            .store(in: &cancellables)
        
        controller.virtualDisplay.$scaleFactor
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.displayScaleFactor = value
            }
            .store(in: &cancellables)
        
        controller.virtualDisplay.$isCursorInside
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.isCursorInside = value
            }
            .store(in: &cancellables)
        
        // Observe controller state
        controller.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.isRecording = value
            }
            .store(in: &cancellables)
        
        controller.$recordingDuration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.recordingDuration = value
            }
            .store(in: &cancellables)
        
        controller.$isStreaming
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.isStreaming = value
            }
            .store(in: &cancellables)
        
        controller.$streamingFrameRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                self?.streamingFrameRate = value
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    
    var resolutionText: String {
        guard displayResolution != .zero else { return "—" }
        return "\(Int(displayResolution.width))×\(Int(displayResolution.height))"
    }
    
    var scaleText: String {
        guard displayScaleFactor > 0 else { return "—" }
        return "\(Int(displayScaleFactor))x"
    }
    
    var orientationText: String {
        guard displayResolution != .zero else { return "—" }
        return displayResolution.width > displayResolution.height ? "Landscape" : "Portrait"
    }
    
    var cursorInsideText: String {
        isCursorInside ? "Yes" : "No"
    }
    
    var recordingDurationText: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var streamingDataText: String {
        ByteCountFormatter.string(fromByteCount: streamingBytesOutput, countStyle: .file)
    }
    
    // MARK: - Actions
    
    func toggleDisplay() {
        if isDisplayActive {
            // Stop everything
            Task {
                if isRecording {
                    _ = try? await controller.stopRecording()
                }
                if isStreaming {
                    controller.stopStreaming()
                }
            }
            controller.stop()
            isDisplayActive = false
            isDisplayReady = false
        } else {
            // Recreate controller with selected preset
            controller = VirtualDisplayController(preset: selectedPreset)
            observeController()
            controller.start()
            isDisplayActive = true
            recordingPulse = true
        }
    }
    
    func toggleRecording() {
        if isRecording {
            Task {
                if let url = try? await controller.stopRecording() {
                    lastRecordingURL = url
                }
            }
        } else {
            // Show save panel to let user choose location
            let savePanel = NSSavePanel()
            savePanel.title = "Save Recording"
            savePanel.nameFieldLabel = "File Name:"
            savePanel.directoryURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            
            // Generate default filename with timestamp
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let filename = "VirtualDisplay_\(dateFormatter.string(from: Date()))"
            savePanel.nameFieldStringValue = filename
            
            // Set allowed file types based on quality
            savePanel.allowedContentTypes = [.mpeg4Movie]
            savePanel.canCreateDirectories = true
            
            // Show the panel
            let response = savePanel.runModal()
            
            guard response == .OK, let outputURL = savePanel.url else {
                return
            }
            
            do {
                let config: RecordingConfiguration
                switch recordingQuality {
                case .standard:
                    config = .standard
                case .high:
                    config = .highQuality
                case .hevc:
                    config = .hevcHighEfficiency
                }
                
                try controller.startRecording(to: outputURL, configuration: config)
            } catch {
                print("Failed to start recording: \(error)")
            }
        }
    }
    
    func toggleStreaming() {
        if isStreaming {
            controller.stopStreaming()
            streamingFrameCount = 0
            streamingBytesOutput = 0
        } else {
            let config: StreamOutputConfiguration
            switch streamingFormat {
            case .h264:
                config = .rtmpStreaming
            case .hevc:
                config = StreamOutputConfiguration(format: .hevcAnnexB, bitrate: 4_000_000)
            case .raw:
                config = StreamOutputConfiguration(format: .rawPixelBuffer)
            }
            
            streamingFrameCount = 0
            streamingBytesOutput = 0
            
            do {
                try controller.startStreaming(configuration: config) { [weak self] data, time, isKeyFrame in
                    Task { @MainActor in
                        self?.streamingFrameCount += 1
                        self?.streamingBytesOutput += Int64(data.count)
                    }
                }
            } catch {
                print("Failed to start streaming: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

enum RecordingQuality: String, CaseIterable {
    case standard
    case high
    case hevc
}

enum StreamingFormat: String, CaseIterable {
    case h264
    case hevc
    case raw
}

// MARK: - Preview

#Preview {
    ContentView()
}

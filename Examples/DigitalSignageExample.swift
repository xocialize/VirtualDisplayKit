//
//  DigitalSignageExample.swift
//  VirtualDisplayKit Examples
//
//  Example showing how to use VirtualDisplayKit for digital signage testing.
//  This is particularly useful when you need to test signage layouts
//  without physical monitors.
//

import SwiftUI
import VirtualDisplayKit
import Combine

// MARK: - Signage Testing View

/// A view for testing digital signage layouts
///
/// This example demonstrates:
/// - Creating portrait and landscape signage displays
/// - Switching between different resolutions
/// - Testing content layouts without physical monitors
///
struct SignageTestingView: View {
    @StateObject private var viewModel = SignageViewModel()
    
    var body: some View {
        HSplitView {
            // Control Panel
            controlPanel
                .frame(minWidth: 250, maxWidth: 300)
            
            // Preview Area
            previewArea
        }
        .frame(minWidth: 900, minHeight: 700)
    }
    
    // MARK: - Control Panel
    
    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Signage Configuration")
                .font(.headline)
            
            Divider()
            
            // Orientation
            VStack(alignment: .leading, spacing: 8) {
                Text("Orientation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Orientation", selection: $viewModel.isPortrait) {
                    Text("Landscape").tag(false)
                    Text("Portrait").tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isDisplayActive)
            }
            
            // Resolution
            VStack(alignment: .leading, spacing: 8) {
                Text("Resolution")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("Resolution", selection: $viewModel.selectedResolution) {
                    Text("1080p").tag(SignageViewModel.Resolution.hd1080)
                    Text("4K").tag(SignageViewModel.Resolution.uhd4k)
                }
                .pickerStyle(.segmented)
                .disabled(viewModel.isDisplayActive)
            }
            
            // Start/Stop
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
            
            Divider()
            
            // Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Status")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Circle()
                        .fill(viewModel.isReady ? Color.green : (viewModel.isDisplayActive ? Color.orange : Color.gray))
                        .frame(width: 10, height: 10)
                    Text(viewModel.statusText)
                        .font(.caption)
                }
                
                if viewModel.isReady {
                    Text("Resolution: \(Int(viewModel.resolution.width))×\(Int(viewModel.resolution.height))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Orientation: \(viewModel.resolution.width < viewModel.resolution.height ? "Portrait" : "Landscape")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text("Instructions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("The virtual display appears as a real monitor in System Settings → Displays. You can:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Label("Drag windows to it", systemImage: "macwindow")
                    Label("Arrange it with other displays", systemImage: "display.2")
                    Label("Use it as signage output", systemImage: "tv")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Preview Area
    
    private var previewArea: some View {
        ZStack {
            Color(NSColor.controlBackgroundColor)
            
            if viewModel.isDisplayActive {
                if viewModel.isReady {
                    VirtualDisplayView(
                        virtualDisplay: viewModel.controller.virtualDisplay,
                        highlightWhenCursorInside: true
                    ) { point in
                        viewModel.controller.moveCursor(to: point)
                    }
                    .padding(20)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Initializing virtual display...")
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "tv")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("Select orientation and resolution,\nthen click Start Display")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
class SignageViewModel: ObservableObject {
    
    enum Resolution {
        case hd1080
        case uhd4k
    }
    
    @Published var isPortrait: Bool = true
    @Published var selectedResolution: Resolution = .hd1080
    @Published var isDisplayActive = false
    @Published var isReady = false
    @Published var resolution: CGSize = .zero
    
    private(set) var controller: VirtualDisplayController!
    private var cancellables = Set<AnyCancellable>()
    
    var statusText: String {
        if !isDisplayActive {
            return "Inactive"
        } else if isReady {
            return "Ready"
        } else {
            return "Starting..."
        }
    }
    
    private var selectedPreset: VirtualDisplayController.ConfigurationPreset {
        switch (selectedResolution, isPortrait) {
        case (.hd1080, false): return .standard1080p
        case (.hd1080, true): return .portrait1080p
        case (.uhd4k, false): return .high4K
        case (.uhd4k, true): return .portrait4K
        }
    }
    
    init() {
        controller = VirtualDisplayController(preset: selectedPreset)
        setupObservers()
    }
    
    private func setupObservers() {
        cancellables.removeAll()
        
        controller.virtualDisplay.$isReady
            .receive(on: DispatchQueue.main)
            .assign(to: &$isReady)
        
        controller.virtualDisplay.$resolution
            .receive(on: DispatchQueue.main)
            .assign(to: &$resolution)
    }
    
    func toggleDisplay() {
        if isDisplayActive {
            controller.stop()
            isDisplayActive = false
            isReady = false
        } else {
            // Recreate controller with selected preset
            controller = VirtualDisplayController(preset: selectedPreset)
            setupObservers()
            controller.start()
            isDisplayActive = true
        }
    }
}

// MARK: - Preview

#Preview {
    SignageTestingView()
}

// MARK: - Integration Guide

/*
 INTEGRATION GUIDE FOR DIGITAL SIGNAGE APPS
 ==========================================
 
 1. Add VirtualDisplayKit to your signage app as a dependency
 
 2. Create a "Test Mode" or "Preview Mode" in your app that uses
    VirtualDisplayKit to simulate the output display:
 
    ```swift
    @StateObject private var controller = VirtualDisplayController(preset: .portrait1080p)
    @State private var isTestMode = false
    
    var body: some View {
        if isTestMode {
            // Show virtual display with your content
            ZStack {
                VirtualDisplayView(virtualDisplay: controller.virtualDisplay)
                
                // Your signage content will appear here when you
                // drag windows to the virtual display
            }
            .onAppear {
                controller.start()
            }
            .onDisappear {
                controller.stop()
            }
        } else {
            // Normal app UI
            SignageControlPanel()
        }
    }
    ```
 
 3. For multi-display signage setups, create multiple controllers
    with unique configurations:
 
    ```swift
    for i in 0..<displayCount {
        var config = VirtualDisplayConfiguration.preset1080pPortrait
        config.name = "Signage Display \(i + 1)"
        config.serialNumber = UInt32(i + 1)
        
        let controller = VirtualDisplayController(configuration: config)
        controller.start()
        controllers.append(controller)
    }
    ```
 
 4. The virtual displays appear in System Settings → Displays
    and can be arranged just like physical monitors.
 
 5. Common signage orientations:
    - Portrait (1080×1920): Kiosks, totems, menu boards
    - Landscape (1920×1080): Video walls, lobby displays
    - Portrait 4K (2160×3840): High-resolution digital posters
    - Landscape 4K (3840×2160): Large format displays
 
 */

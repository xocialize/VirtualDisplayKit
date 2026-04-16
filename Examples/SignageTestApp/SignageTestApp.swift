//
//  SignageTestApp.swift
//  SignageTestApp
//
//  Example application demonstrating VirtualDisplayKit integration
//  for digital signage testing.
//

import SwiftUI
import VirtualDisplayKit
import Combine

@main
struct SignageTestApp: App {
    var body: some Scene {
        WindowGroup {
            SignageContentView()
        }
    }
}

struct SignageContentView: View {
    @StateObject private var viewModel = SignageAppViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "tv.fill")
                    .font(.title)
                Text("Signage Display Tester")
                    .font(.title2.bold())
                Spacer()
                statusBadge
            }
            .padding(.horizontal)
            
            // Main content - the virtual display preview
            Group {
                if viewModel.isRunning {
                    if viewModel.isReady {
                        VirtualDisplayView(
                            virtualDisplay: viewModel.controller.virtualDisplay,
                            highlightWhenCursorInside: true
                        ) { point in
                            viewModel.controller.moveCursor(to: point)
                        }
                    } else {
                        ProgressView("Initializing display...")
                    }
                } else {
                    placeholderView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .padding(.horizontal)
            
            // Info panel
            infoPanel
            
            // Controls
            controlsPanel
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
    }
    
    // MARK: - Subviews
    
    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isReady ? Color.green : (viewModel.isRunning ? Color.orange : Color.gray))
                .frame(width: 8, height: 8)
            Text(viewModel.statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.secondary.opacity(0.1)))
    }
    
    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "display")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Virtual Display Preview")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Select orientation and click \"Start\" to create a virtual display")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.1))
    }
    
    private var infoPanel: some View {
        HStack(spacing: 20) {
            infoItem(title: "Resolution", value: viewModel.resolutionText)
            Divider().frame(height: 30)
            infoItem(title: "Scale", value: viewModel.scaleText)
            Divider().frame(height: 30)
            infoItem(title: "Orientation", value: viewModel.orientationText)
            Divider().frame(height: 30)
            infoItem(title: "Cursor Inside", value: viewModel.isCursorInside ? "Yes" : "No")
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
    
    private func infoItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
    
    private var controlsPanel: some View {
        HStack(spacing: 12) {
            // Orientation picker
            Picker("Orientation", selection: $viewModel.isPortrait) {
                Text("Landscape").tag(false)
                Text("Portrait").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            .disabled(viewModel.isRunning)
            
            Button(action: viewModel.toggleDisplay) {
                Label(viewModel.isRunning ? "Stop" : "Start", systemImage: viewModel.isRunning ? "stop.fill" : "play.fill")
                    .frame(width: 100)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isRunning ? .red : .green)
            
            Spacer()
            
            Text("Click on the preview to move the cursor to that position")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

// MARK: - View Model

@MainActor
class SignageAppViewModel: ObservableObject {
    @Published var isPortrait: Bool = true
    @Published var isRunning = false
    @Published var isReady = false
    @Published var resolution: CGSize = .zero
    @Published var isCursorInside = false
    
    private(set) var controller: VirtualDisplayController!
    
    var statusText: String {
        if !isRunning { return "Inactive" }
        if isReady { return "Active" }
        return "Starting..."
    }
    
    var resolutionText: String {
        guard resolution != .zero else { return "—" }
        return "\(Int(resolution.width))×\(Int(resolution.height))"
    }
    
    var scaleText: String {
        guard isReady else { return "—" }
        let scale = controller.virtualDisplay.scaleFactor
        return "\(Int(scale))x"
    }
    
    var orientationText: String {
        guard resolution != .zero else { return "—" }
        return resolution.width < resolution.height ? "Portrait" : "Landscape"
    }
    
    private var selectedPreset: VirtualDisplayController.ConfigurationPreset {
        isPortrait ? .portrait1080p : .standard1080p
    }
    
    init() {
        controller = VirtualDisplayController(preset: selectedPreset)
        setupObservers()
    }
    
    private func setupObservers() {
        controller.virtualDisplay.$isReady
            .receive(on: DispatchQueue.main)
            .assign(to: &$isReady)
        
        controller.virtualDisplay.$resolution
            .receive(on: DispatchQueue.main)
            .assign(to: &$resolution)
        
        controller.virtualDisplay.$isCursorInside
            .receive(on: DispatchQueue.main)
            .assign(to: &$isCursorInside)
    }
    
    func toggleDisplay() {
        if isRunning {
            controller.stop()
            isRunning = false
            isReady = false
        } else {
            // Recreate controller with selected preset
            controller = VirtualDisplayController(preset: selectedPreset)
            setupObservers()
            controller.start()
            isRunning = true
        }
    }
}

// MARK: - Preview

#Preview {
    SignageContentView()
}

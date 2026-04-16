//
//  AppKitExampleApp.swift
//  VirtualDisplayKit Examples
//
//  Example AppKit application demonstrating VirtualDisplayKit usage.
//  Perfect for embedding in existing AppKit applications.
//

import AppKit
import VirtualDisplayKit
import Combine

// MARK: - App Delegate Example

/// Example AppDelegate for an AppKit-based virtual display application
///
/// To use this example:
/// 1. Create a new macOS AppKit app in Xcode (not SwiftUI)
/// 2. Add VirtualDisplayKit as a local package dependency
/// 3. Replace the AppDelegate content with this code
/// 4. Delete the storyboard references and set NSPrincipalClass to ExampleAppDelegate
///
final class ExampleAppDelegate: NSObject, NSApplicationDelegate {
    
    private var window: NSWindow!
    private var viewController: ExampleViewController!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        viewController = ExampleViewController()
        
        window = NSWindow(contentViewController: viewController)
        window.title = "Virtual Display Example"
        window.setContentSize(NSSize(width: 1280, height: 800))
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - View Controller Example

/// Example ViewController demonstrating VirtualDisplayKit integration
final class ExampleViewController: NSViewController {
    
    private var controller: VirtualDisplayController!
    private var displayView: VirtualDisplayNSView!
    private var statusLabel: NSTextField!
    private var startStopButton: NSButton!
    private var presetPopup: NSPopUpButton!
    private var cancellables = Set<AnyCancellable>()
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupController()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Toolbar area
        let toolbar = NSView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        view.addSubview(toolbar)
        
        // Preset popup
        presetPopup = NSPopUpButton()
        presetPopup.translatesAutoresizingMaskIntoConstraints = false
        presetPopup.addItems(withTitles: ["1080p", "1080p Portrait", "4K", "4K Portrait"])
        presetPopup.target = self
        presetPopup.action = #selector(presetChanged)
        toolbar.addSubview(presetPopup)
        
        // Start/Stop button
        startStopButton = NSButton(title: "Start", target: self, action: #selector(toggleDisplay))
        startStopButton.translatesAutoresizingMaskIntoConstraints = false
        startStopButton.bezelStyle = .rounded
        toolbar.addSubview(startStopButton)
        
        // Status label
        statusLabel = NSTextField(labelWithString: "Inactive")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(statusLabel)
        
        // Display view container
        let displayContainer = NSView()
        displayContainer.translatesAutoresizingMaskIntoConstraints = false
        displayContainer.wantsLayer = true
        displayContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.addSubview(displayContainer)
        
        // Display view
        displayView = VirtualDisplayNSView()
        displayView.translatesAutoresizingMaskIntoConstraints = false
        displayContainer.addSubview(displayView)
        
        // Layout
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44),
            
            presetPopup.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            presetPopup.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 12),
            
            startStopButton.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            startStopButton.leadingAnchor.constraint(equalTo: presetPopup.trailingAnchor, constant: 12),
            
            statusLabel.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -12),
            
            displayContainer.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            displayContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            displayContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            displayContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            displayView.centerXAnchor.constraint(equalTo: displayContainer.centerXAnchor),
            displayView.centerYAnchor.constraint(equalTo: displayContainer.centerYAnchor),
            displayView.widthAnchor.constraint(lessThanOrEqualTo: displayContainer.widthAnchor, constant: -40),
            displayView.heightAnchor.constraint(lessThanOrEqualTo: displayContainer.heightAnchor, constant: -40),
        ])
    }
    
    private func setupController() {
        controller = VirtualDisplayController(preset: selectedPreset)
        
        // Attach the display view
        displayView.attach(controller.virtualDisplay)
        displayView.onTap = { [weak self] point in
            self?.controller.moveCursor(to: point)
        }
        
        // Observe state changes
        controller.virtualDisplay.$isReady
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReady in
                self?.updateStatus()
            }
            .store(in: &cancellables)
        
        controller.virtualDisplay.$resolution
            .receive(on: DispatchQueue.main)
            .sink { [weak self] resolution in
                self?.updateStatus()
            }
            .store(in: &cancellables)
    }
    
    private var selectedPreset: VirtualDisplayController.ConfigurationPreset {
        switch presetPopup.indexOfSelectedItem {
        case 0: return .standard1080p
        case 1: return .portrait1080p
        case 2: return .high4K
        case 3: return .portrait4K
        default: return .standard1080p
        }
    }
    
    private var isDisplayActive = false
    
    // MARK: - Actions
    
    @objc private func presetChanged(_ sender: NSPopUpButton) {
        // Only allow changing preset when display is stopped
        if isDisplayActive {
            // Reset popup to current selection
        }
    }
    
    @objc private func toggleDisplay() {
        if isDisplayActive {
            controller.stop()
            isDisplayActive = false
            startStopButton.title = "Start"
            presetPopup.isEnabled = true
            updateStatus()
        } else {
            // Recreate controller with selected preset
            cancellables.removeAll()
            controller = VirtualDisplayController(preset: selectedPreset)
            displayView.attach(controller.virtualDisplay)
            displayView.onTap = { [weak self] point in
                self?.controller.moveCursor(to: point)
            }
            
            // Re-observe state changes
            controller.virtualDisplay.$isReady
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateStatus()
                }
                .store(in: &cancellables)
            
            controller.virtualDisplay.$resolution
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateStatus()
                }
                .store(in: &cancellables)
            
            controller.start()
            isDisplayActive = true
            startStopButton.title = "Stop"
            presetPopup.isEnabled = false
            updateStatus()
        }
    }
    
    private func updateStatus() {
        if !isDisplayActive {
            statusLabel.stringValue = "Inactive"
            statusLabel.textColor = .secondaryLabelColor
        } else if controller.virtualDisplay.isReady {
            let res = controller.virtualDisplay.resolution
            statusLabel.stringValue = "Ready - \(Int(res.width))×\(Int(res.height))"
            statusLabel.textColor = .systemGreen
        } else {
            statusLabel.stringValue = "Starting..."
            statusLabel.textColor = .systemOrange
        }
    }
}

// MARK: - Embedding Example

/// Example showing how to embed a virtual display in an existing view hierarchy
final class EmbeddedDisplayExample {
    
    private var controller: VirtualDisplayController?
    private var displayView: VirtualDisplayNSView?
    
    /// Creates an embedded virtual display view
    func createEmbeddedDisplay(in parentView: NSView, preset: VirtualDisplayController.ConfigurationPreset = .standard1080p) -> VirtualDisplayNSView {
        // Create controller and view
        let controller = VirtualDisplayController(preset: preset)
        let displayView = VirtualDisplayNSView()
        
        displayView.translatesAutoresizingMaskIntoConstraints = false
        displayView.attach(controller.virtualDisplay)
        parentView.addSubview(displayView)
        
        // Example: Position in bottom-right corner as a preview
        NSLayoutConstraint.activate([
            displayView.widthAnchor.constraint(equalToConstant: 320),
            displayView.heightAnchor.constraint(equalToConstant: 180),
            displayView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor, constant: -20),
            displayView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor, constant: -20),
        ])
        
        // Start the display
        controller.start()
        
        // Store references
        self.controller = controller
        self.displayView = displayView
        
        return displayView
    }
    
    /// Stops and removes the embedded display
    func removeEmbeddedDisplay() {
        controller?.stop()
        displayView?.removeFromSuperview()
        controller = nil
        displayView = nil
    }
}

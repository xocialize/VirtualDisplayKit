//
//  VirtualDisplayDemoApp.swift
//  VirtualDisplayDemo
//
//  A demo application showcasing VirtualDisplayKit capabilities
//  including virtual display creation, recording, and streaming.
//

import SwiftUI
import VirtualDisplayKit

@main
struct VirtualDisplayDemoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        Settings {
            SettingsView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure app appearance
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Settings View

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            RecordingSettingsView()
                .tabItem {
                    Label("Recording", systemImage: "record.circle")
                }
            
            StreamingSettingsView()
                .tabItem {
                    Label("Streaming", systemImage: "antenna.radiowaves.left.and.right")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("defaultResolution") var defaultResolution = "1080p"
    @AppStorage("showCursor") var showCursor = true
    @AppStorage("highlightOnHover") var highlightOnHover = true
    
    var body: some View {
        Form {
            Picker("Default Resolution", selection: $defaultResolution) {
                Text("1080p (1920×1080)").tag("1080p")
                Text("4K (3840×2160)").tag("4K")
                Text("Signage").tag("signage")
            }
            
            Toggle("Show Cursor in Display", isOn: $showCursor)
            Toggle("Highlight Window When Cursor Inside", isOn: $highlightOnHover)
        }
        .padding()
    }
}

struct RecordingSettingsView: View {
    @AppStorage("recordingQuality") var recordingQuality = "standard"
    @AppStorage("recordingFrameRate") var recordingFrameRate = 30
    
    var body: some View {
        Form {
            Picker("Quality", selection: $recordingQuality) {
                Text("Standard").tag("standard")
                Text("High Quality").tag("high")
                Text("HEVC High Efficiency").tag("hevc")
            }
            
            Picker("Frame Rate", selection: $recordingFrameRate) {
                Text("30 fps").tag(30)
                Text("60 fps").tag(60)
            }
        }
        .padding()
    }
}

struct StreamingSettingsView: View {
    @AppStorage("streamingBitrate") var streamingBitrate = 4500
    @AppStorage("streamingKeyframeInterval") var streamingKeyframeInterval = 2.0
    
    var body: some View {
        Form {
            Picker("Bitrate", selection: $streamingBitrate) {
                Text("3 Mbps (Low)").tag(3000)
                Text("4.5 Mbps (Standard)").tag(4500)
                Text("8 Mbps (High)").tag(8000)
            }
            
            Picker("Keyframe Interval", selection: $streamingKeyframeInterval) {
                Text("1 second").tag(1.0)
                Text("2 seconds").tag(2.0)
                Text("4 seconds").tag(4.0)
            }
        }
        .padding()
    }
}

//
//  VirtualDisplayKitTests.swift
//  VirtualDisplayKit
//

import XCTest
@testable import VirtualDisplayKit

final class VirtualDisplayKitTests: XCTestCase {
    
    // MARK: - Configuration Tests
    
    func testDefaultConfiguration() {
        let config = VirtualDisplayConfiguration()
        
        XCTAssertEqual(config.name, "Virtual Display")
        XCTAssertEqual(config.maxWidth, 3840)
        XCTAssertEqual(config.maxHeight, 2160)
        XCTAssertEqual(config.hiDPIEnabled, true)
        XCTAssertEqual(config.refreshRate, 60)
        XCTAssertEqual(config.showCursor, true)
    }
    
    func testPreset1080p() {
        let config = VirtualDisplayConfiguration.preset1080p
        
        XCTAssertEqual(config.maxWidth, 1920)
        XCTAssertEqual(config.maxHeight, 1080)
        XCTAssert(config.displayModes.contains { $0.width == 1920 && $0.height == 1080 })
    }
    
    func testPreset4K() {
        let config = VirtualDisplayConfiguration.preset4K
        
        XCTAssertEqual(config.maxWidth, 3840)
        XCTAssertEqual(config.maxHeight, 2160)
        XCTAssert(config.displayModes.contains { $0.width == 3840 && $0.height == 2160 })
    }
    
    func testPreset1080pPortrait() {
        let config = VirtualDisplayConfiguration.preset1080pPortrait

        XCTAssertEqual(config.maxWidth, 1080)
        XCTAssertEqual(config.maxHeight, 1920)
        XCTAssert(config.displayModes.contains { $0.width == 1080 && $0.height == 1920 })
    }

    func testPreset4KPortrait() {
        let config = VirtualDisplayConfiguration.preset4KPortrait

        XCTAssertEqual(config.maxWidth, 2160)
        XCTAssertEqual(config.maxHeight, 3840)
        XCTAssert(config.displayModes.contains { $0.height > $0.width })
    }
    
    // MARK: - Display Mode Tests
    
    func testDisplayModeAspectRatio() {
        let mode = DisplayMode(width: 1920, height: 1080, refreshRate: 60)
        
        XCTAssertEqual(mode.aspectRatio, 16.0/9.0, accuracy: 0.001)
        XCTAssertEqual(mode.size, CGSize(width: 1920, height: 1080))
    }
    
    func testDisplayModeEquality() {
        let mode1 = DisplayMode(width: 1920, height: 1080, refreshRate: 60)
        let mode2 = DisplayMode(width: 1920, height: 1080, refreshRate: 60)
        let mode3 = DisplayMode(width: 1920, height: 1080, refreshRate: 30)
        
        XCTAssertEqual(mode1, mode2)
        XCTAssertNotEqual(mode1, mode3)
    }
    
    // MARK: - Virtual Display Tests
    
    @MainActor
    func testVirtualDisplayInitialState() {
        let display = VirtualDisplay()
        
        XCTAssertNil(display.displayID)
        XCTAssertEqual(display.resolution, .zero)
        XCTAssertEqual(display.scaleFactor, 1.0)
        XCTAssertFalse(display.isReady)
        XCTAssertFalse(display.isCursorInside)
    }
    
    @MainActor
    func testVirtualDisplayWithCustomConfiguration() {
        let config = VirtualDisplayConfiguration(
            name: "Test Display",
            maxWidth: 1920,
            maxHeight: 1080
        )
        let display = VirtualDisplay(configuration: config)
        
        XCTAssertEqual(display.configuration.name, "Test Display")
        XCTAssertEqual(display.configuration.maxWidth, 1920)
        XCTAssertEqual(display.configuration.maxHeight, 1080)
    }
    
    // MARK: - Controller Tests
    
    @MainActor
    func testControllerInitialization() {
        let controller = VirtualDisplayController()
        
        XCTAssertFalse(controller.isReady)
        XCTAssertEqual(controller.resolution, .zero)
        XCTAssertNil(controller.displayID)
    }
    
    @MainActor
    func testControllerPresets() {
        let controller1 = VirtualDisplayController(preset: .standard1080p)
        XCTAssertEqual(controller1.virtualDisplay.configuration.maxWidth, 1920)
        
        let controller2 = VirtualDisplayController(preset: .high4K)
        XCTAssertEqual(controller2.virtualDisplay.configuration.maxWidth, 3840)
        
        let controller3 = VirtualDisplayController(preset: .portrait1080p)
        XCTAssert(controller3.virtualDisplay.configuration.displayModes.contains { $0.height > $0.width })
    }
}

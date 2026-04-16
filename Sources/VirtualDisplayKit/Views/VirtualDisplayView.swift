//
//  VirtualDisplayView.swift
//  VirtualDisplayKit
//
//  SwiftUI view for displaying a virtual display stream.
//

import SwiftUI
import Combine

/// A SwiftUI view that displays the contents of a virtual display
public struct VirtualDisplayView: View {
    
    // MARK: - Properties
    
    @ObservedObject private var virtualDisplay: VirtualDisplay
    
    private let onTap: ((CGPoint) -> Void)?
    private let highlightWhenCursorInside: Bool
    
    // MARK: - Initialization
    
    /// Creates a new virtual display view
    /// - Parameters:
    ///   - virtualDisplay: The virtual display to show
    ///   - highlightWhenCursorInside: Whether to highlight the view when the cursor is in the virtual display
    ///   - onTap: Closure called when the view is tapped, with the display coordinates
    public init(
        virtualDisplay: VirtualDisplay,
        highlightWhenCursorInside: Bool = true,
        onTap: ((CGPoint) -> Void)? = nil
    ) {
        self.virtualDisplay = virtualDisplay
        self.highlightWhenCursorInside = highlightWhenCursorInside
        self.onTap = onTap
    }
    
    // MARK: - Body
    
    public var body: some View {
        VirtualDisplayViewRepresentable(
            virtualDisplay: virtualDisplay,
            onTap: onTap
        )
        .aspectRatio(aspectRatio, contentMode: .fit)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: highlightWhenCursorInside && virtualDisplay.isCursorInside ? 3 : 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Computed Properties
    
    private var aspectRatio: CGFloat? {
        guard virtualDisplay.resolution != .zero else { return 16/9 }
        return virtualDisplay.resolution.width / virtualDisplay.resolution.height
    }
    
    private var backgroundColor: Color {
        virtualDisplay.isReady ? Color.black : Color.gray.opacity(0.3)
    }
    
    private var borderColor: Color {
        if highlightWhenCursorInside && virtualDisplay.isCursorInside {
            return Color.accentColor
        }
        return Color.gray.opacity(0.3)
    }
}

// MARK: - NSViewRepresentable

private struct VirtualDisplayViewRepresentable: NSViewRepresentable {
    let virtualDisplay: VirtualDisplay
    let onTap: ((CGPoint) -> Void)?
    
    func makeNSView(context: Context) -> VirtualDisplayContainerView {
        let view = VirtualDisplayContainerView()
        view.onTap = onTap
        return view
    }
    
    func updateNSView(_ nsView: VirtualDisplayContainerView, context: Context) {
        nsView.onTap = onTap
        
        guard let displayID = virtualDisplay.displayID,
              virtualDisplay.resolution != .zero else {
            nsView.renderer?.stopStream()
            return
        }
        
        nsView.configure(
            displayID: displayID,
            resolution: virtualDisplay.resolution,
            scaleFactor: virtualDisplay.scaleFactor,
            backend: virtualDisplay.configuration.streamingBackend,
            showCursor: virtualDisplay.configuration.showCursor
        )
    }
}

// MARK: - Container View

private final class VirtualDisplayContainerView: NSView {
    var renderer: DisplayStreamRenderer?
    var onTap: ((CGPoint) -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        wantsLayer = true
        
        // Add click gesture
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        addGestureRecognizer(clickGesture)
    }
    
    func configure(displayID: CGDirectDisplayID, resolution: CGSize, scaleFactor: CGFloat, backend: StreamingBackend, showCursor: Bool) {
        if renderer == nil {
            let newRenderer = DisplayStreamRenderer(frame: bounds, backend: backend, showCursor: showCursor)
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
        
        renderer?.configure(displayID: displayID, resolution: resolution, scaleFactor: scaleFactor)
    }
    
    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        guard let renderer = renderer else { return }
        let viewPoint = gesture.location(in: renderer)
        
        if let displayPoint = renderer.convertToDisplayCoordinates(viewPoint) {
            onTap?(displayPoint)
        }
    }
}

// MARK: - Preview

#if DEBUG
@available(macOS 14.0, *)
#Preview {
    VStack {
        Text("Virtual Display Preview")
            .font(.headline)
        
        // Note: Preview won't actually show a display stream
        // This is just to preview the UI structure
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .aspectRatio(16/9, contentMode: .fit)
            .overlay(
                Text("Virtual Display\n(Preview Only)")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    .padding()
    .frame(width: 400, height: 300)
}
#endif

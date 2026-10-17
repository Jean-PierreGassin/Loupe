import AppKit
import SwiftUI

@MainActor @Observable final class PanelHover {
    fileprivate(set) var isHovering = false
}

final class OverlayPanel: NSPanel {
    private let acceptsKey: Bool

    init(acceptsKey: Bool = false, @ViewBuilder content: () -> some View) {
        self.acceptsKey = acceptsKey
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .statusBar
        isFloatingPanel = true
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hover = PanelHover()
        let host = OverlayHostingView(rootView: content().environment(\.colorScheme, .dark).environment(hover))
        host.hover = hover
        contentView = host
        setContentSize(host.fittingSize)
    }

    override var canBecomeKey: Bool { acceptsKey }

    func present(at origin: (NSSize) -> NSPoint) {
        setFrameOrigin(origin(frame.size))
        orderFrontRegardless()
        if acceptsKey {
            makeKey()
        }
    }
}

private final class OverlayHostingView<Content: View>: NSHostingView<Content> {
    var hover: PanelHover?
    private lazy var hoverArea = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if !trackingAreas.contains(hoverArea) {
            addTrackingArea(hoverArea)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if event.trackingArea === hoverArea { hover?.isHovering = true }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if event.trackingArea === hoverArea { hover?.isHovering = false }
    }
}

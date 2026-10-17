import AppKit
import SwiftUI

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

        let host = NSHostingController(rootView: content().environment(\.colorScheme, .dark))
        host.sizingOptions = [.preferredContentSize]
        contentViewController = host
        setContentSize(host.view.fittingSize)
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

import AppKit
import LoupeCore
import SwiftUI

@MainActor final class OverlayController {
    private unowned let model: AppModel
    private var setup: OverlayPanel?
    private var bubble: OverlayPanel?
    private var countdown: OverlayPanel?
    private var controlBar: OverlayPanel?

    private static let bubbleInset = CameraBubbleView.shadowInset
    private static let margin: CGFloat = 28

    init(model: AppModel) {
        self.model = model
    }

    private var screen: NSRect {
        model.setup.display.flatMap { NSScreen.matching($0.id)?.visibleFrame } ?? NSScreen.main?.visibleFrame ?? .zero
    }

    var bubblePlacement: (center: NormPoint, size: Double)? {
        guard let bubble, bubble.isVisible, let display = model.setup.display else { return nil }
        let frame = display.frame
        return (
            NormPoint((bubble.frame.midX - frame.minX) / frame.width, (frame.maxY - bubble.frame.midY) / frame.height),
            model.setup.bubbleSize.diameter / frame.height
        )
    }

    func showSetup() {
        setup?.close()
        let panel = OverlayPanel(acceptsKey: true) { SetupView().environment(model) }
        let screen = screen
        panel.present { NSPoint(x: screen.maxX - $0.width - Self.margin, y: screen.midY - $0.height / 2) }
        setup = panel
        NSApp.activate()
    }

    func hideSetup() {
        setup?.close()
        setup = nil
    }

    func showBubble() {
        let screen = screen
        let origin = NSPoint(x: screen.minX + Self.margin - Self.bubbleInset, y: screen.minY + Self.margin - Self.bubbleInset)
        if let bubble, bubble.isVisible, screen.contains(bubble.frame.origin) {
            return
        }
        bubble?.close()
        let panel = OverlayPanel { CameraBubbleView().environment(model) }
        panel.present { _ in origin }
        bubble = panel
    }

    func hideBubble() {
        bubble?.close()
        bubble = nil
    }

    func showCountdown() {
        guard countdown == nil else { return }
        let panel = OverlayPanel { CountdownView().environment(model) }
        let screen = screen
        panel.present { NSPoint(x: screen.midX - $0.width / 2, y: screen.midY - $0.height / 2) }
        panel.ignoresMouseEvents = true
        countdown = panel
    }

    func hideCountdown() {
        countdown?.close()
        countdown = nil
    }

    func showControlBar() {
        controlBar?.close()
        let panel = OverlayPanel { ControlBarView().environment(model) }
        let screen = screen
        panel.present { NSPoint(x: screen.midX - $0.width / 2, y: screen.minY + Self.margin) }
        controlBar = panel
    }

    func hideAll() {
        [setup, bubble, countdown, controlBar].forEach { $0?.close() }
        (setup, bubble, countdown, controlBar) = (nil, nil, nil, nil)
    }
}

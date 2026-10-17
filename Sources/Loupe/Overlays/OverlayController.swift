import AppKit
import LoupeCore
import SwiftUI

@MainActor final class OverlayController {
    private unowned let model: AppModel
    private var setup: OverlayPanel?
    private var bubble: OverlayPanel?
    private var countdown: OverlayPanel?
    private var controlBar: OverlayPanel?

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
        if let circle = bubbleCircle, screen.contains(circle) {
            return
        }
        bubble?.close()
        let inset = (CameraBubbleView.extent - model.setup.bubbleSize.diameter) / 2
        let panel = OverlayPanel { CameraBubbleView().environment(model) }
        panel.present { _ in NSPoint(x: screen.minX + Self.margin - inset, y: screen.minY + Self.margin - inset) }
        bubble = panel
    }

    func keepBubbleOnScreen() {
        guard let bubble, let circle = bubbleCircle else { return }
        let screen = screen.insetBy(dx: 8, dy: 8)
        let dx = max(0, screen.minX - circle.minX) - max(0, circle.maxX - screen.maxX)
        let dy = max(0, screen.minY - circle.minY) - max(0, circle.maxY - screen.maxY)
        guard dx != 0 || dy != 0 else { return }
        bubble.animator().setFrameOrigin(NSPoint(x: bubble.frame.minX + dx, y: bubble.frame.minY + dy))
    }

    private var bubbleCircle: NSRect? {
        guard let bubble, bubble.isVisible else { return nil }
        let diameter = model.setup.bubbleSize.diameter
        return NSRect(x: bubble.frame.midX - diameter / 2, y: bubble.frame.midY - diameter / 2, width: diameter, height: diameter)
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

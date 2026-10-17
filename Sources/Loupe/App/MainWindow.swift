import AppKit
import SwiftUI

@MainActor final class MainWindow {
    weak var window: NSWindow?
    var reopen: (() -> Void)?

    func show() {
        NSApp.activate()
        if let window {
            window.makeKeyAndOrderFront(nil)
        } else {
            reopen?()
        }
    }

    func hide() {
        window?.orderOut(nil)
    }
}

struct WindowReader: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in
            if let window = view.window { onResolve(window) }
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

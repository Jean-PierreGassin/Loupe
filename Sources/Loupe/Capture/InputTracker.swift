import AppKit
import LoupeCore

@MainActor final class InputTracker {
    private struct Mark {
        let time: Double
        let location: CGPoint
    }

    private var monitor: Any?
    private var sampler: Task<Void, Never>?
    private var clicks: [Mark] = []
    private var keys: [Mark] = []
    private var samples: [Mark] = []
    private var exposedApps: Set<pid_t> = []

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            let isKey = event.type == .keyDown
            let isShortcut = !event.modifierFlags.isDisjoint(with: [.command, .control])
            MainActor.assumeIsolated {
                if !isKey {
                    self?.recordClick()
                } else if !isShortcut {
                    self?.recordKey()
                }
            }
        }
        sampler = Task { [weak self] in
            while !Task.isCancelled, let self {
                self.sample()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    func stop(start: Double, display: CGRect) -> (events: [InputEvent], cursor: [CursorSample]) {
        monitor.map(NSEvent.removeMonitor)
        monitor = nil
        sampler?.cancel()

        let normalize = { (location: CGPoint) in
            NormPoint((location.x - display.minX) / display.width, (location.y - display.minY) / display.height)
        }
        let events = clicks.map { InputEvent(t: $0.time - start, kind: .click, position: normalize($0.location)) }
            + keys.map { InputEvent(t: $0.time - start, kind: .key, position: normalize($0.location)) }
        let cursor = samples.map { CursorSample(t: $0.time - start, position: normalize($0.location)) }
        return (events.filter { $0.t >= 0 }.sorted { $0.t < $1.t }, cursor)
    }

    private func recordClick() {
        clicks.append(Mark(time: HostClock.now.seconds, location: Self.pointer))
    }

    private func recordKey() {
        let time = HostClock.now.seconds
        let pointer = Self.pointer
        let app = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let expose = app.map { exposedApps.insert($0).inserted } ?? false
        Task.detached(priority: .userInitiated) { [weak self] in
            if expose, let app {
                FocusLocator.exposeAccessibility(of: app)
            }
            let location = FocusLocator.textFocus() ?? pointer
            await self?.append(key: Mark(time: time, location: location))
        }
    }

    private func append(key: Mark) {
        keys.append(key)
    }

    private func sample() {
        let mark = Mark(time: HostClock.now.seconds, location: Self.pointer)
        guard let last = samples.last else { return samples.append(mark) }
        guard last.location != mark.location else { return }
        if mark.time - last.time > 0.05 {
            samples.append(Mark(time: mark.time - 0.016, location: last.location))
        }
        samples.append(mark)
    }

    private static var pointer: CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }
}

import AppKit
import LoupeCore
import Synchronization

@MainActor final class InputTracker {
    struct Mark: Sendable {
        let time: Double
        let location: CGPoint
    }

    struct KeyMark: Sendable {
        let time: Double
        let pointer: CGPoint
        var focus: CGPoint?
        var resolved = false
    }

    private struct FocusState: Sendable {
        var keys: [KeyMark] = []
        var checkedApps: Set<pid_t> = []
        var exposedApps: Set<pid_t> = []
    }

    private var monitor: Any?
    private var sampler: Task<Void, Never>?
    private var clicks: [Mark] = []
    private var samples: [Mark] = []
    nonisolated private let focus = Mutex(FocusState())
    private let focusQueue = DispatchQueue(label: "io.github.jean-pierregassin.Loupe.focus", qos: .userInitiated)

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
        focusQueue.sync {}
        let state = focus.withLock { $0 }
        focusQueue.async { state.exposedApps.forEach(FocusLocator.restoreAccessibility) }

        let normalize = { (location: CGPoint) in
            NormPoint((location.x - display.minX) / display.width, (location.y - display.minY) / display.height)
        }
        let events = clicks.map { InputEvent(t: $0.time - start, kind: .click, position: normalize($0.location)) }
            + Self.locate(state.keys).map { InputEvent(t: $0.time - start, kind: .key, position: normalize($0.location)) }
        let cursor = samples.map { CursorSample(t: $0.time - start, position: normalize($0.location)) }
        return (events.filter { $0.t >= 0 }.sorted { $0.t < $1.t }, cursor)
    }

    private func recordClick() {
        clicks.append(Mark(time: HostClock.now.seconds, location: Self.pointer))
    }

    private func recordKey() {
        let mark = KeyMark(time: HostClock.now.seconds, pointer: Self.pointer)
        let app = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let index = focus.withLock { $0.keys.append(mark); return $0.keys.count - 1 }
        focusQueue.async { [self] in
            guard focus.withLock({ $0.keys.count - 1 == index }) else { return }
            if let app, focus.withLock({ $0.checkedApps.insert(app).inserted }), FocusLocator.exposeAccessibility(of: app) {
                focus.withLock { _ = $0.exposedApps.insert(app) }
            }
            let location = FocusLocator.textFocus()
            focus.withLock {
                $0.keys[index].focus = location
                $0.keys[index].resolved = true
            }
        }
    }

    nonisolated static func locate(_ keys: [KeyMark]) -> [Mark] {
        var upcoming: CGPoint?
        return keys.reversed().map { key in
            if key.resolved {
                upcoming = key.focus
            }
            return Mark(time: key.time, location: upcoming ?? key.pointer)
        }
        .reversed()
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

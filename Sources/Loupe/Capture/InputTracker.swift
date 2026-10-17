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

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            let isKey = event.type == .keyDown
            MainActor.assumeIsolated { self?.record(isKey: isKey) }
        }
        sampler = Task { [weak self] in
            while !Task.isCancelled {
                self?.sample()
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

    private func record(isKey: Bool) {
        let mark = Mark(time: HostClock.now.seconds, location: Self.pointer)
        if isKey { keys.append(mark) } else { clicks.append(mark) }
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

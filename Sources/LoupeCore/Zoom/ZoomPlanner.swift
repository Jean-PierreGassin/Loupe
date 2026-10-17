import Foundation

public enum ZoomPlanner {
    static let leadIn = 0.45
    static let holdAfter = 1.6
    static let mergeGap = 0.9
    static let typingGap = 1.2
    static let minTypingKeys = 3
    static let minDuration = 1.2

    public static func segments(for events: [InputEvent], duration: Double, scale: Double) -> [ZoomSegment] {
        let activities = (clicks(in: events) + typingBursts(in: events)).sorted { $0.lowerBound < $1.lowerBound }
        var spans: [ClosedRange<Double>] = []
        for activity in activities {
            let span = max(0, activity.lowerBound - leadIn)...min(duration, activity.upperBound + holdAfter)
            if let last = spans.last, span.lowerBound <= last.upperBound + mergeGap {
                spans[spans.count - 1] = last.lowerBound...max(last.upperBound, span.upperBound)
            } else {
                spans.append(span)
            }
        }
        return spans
            .filter { $0.upperBound - $0.lowerBound >= minDuration }
            .map { ZoomSegment(start: $0.lowerBound, end: $0.upperBound, scale: scale, isAuto: true) }
    }

    public static func cameraPath(for project: Project, fps: Double = 60) -> CameraPath {
        cameraPath(segments: project.zooms, events: project.events, cursor: project.cursor, duration: project.duration, fps: fps)
    }

    public static func cameraPath(
        segments: [ZoomSegment],
        events: [InputEvent],
        cursor: [CursorSample],
        duration: Double,
        fps: Double = 60
    ) -> CameraPath {
        let frameCount = max(1, Int((duration * fps).rounded(.up)) + 1)
        let segments = segments.sorted { $0.start < $1.start }
        let events = events.sorted { $0.t < $1.t }
        let pointer = CursorTrack(samples: cursor)
        let dt = 1 / fps

        var depth = Spring(value: 0, omega: 6.5)
        var panX = Spring(value: 0.5, omega: 5.5)
        var panY = Spring(value: 0.5, omega: 5.5)
        var focus = NormPoint.center
        var activeSegment: UUID?
        var segmentIndex = 0
        var states: [CameraState] = []
        states.reserveCapacity(frameCount)

        for frame in 0..<frameCount {
            let t = Double(frame) * dt
            while segmentIndex < segments.count, segments[segmentIndex].end <= t {
                segmentIndex += 1
            }
            let segment = segments.indices.contains(segmentIndex) && segments[segmentIndex].start <= t ? segments[segmentIndex] : nil
            let targetScale = max(1, segment?.scale ?? 1)

            if let segment {
                let position = pointer.position(at: t) ?? focus
                if activeSegment != segment.id {
                    activeSegment = segment.id
                    focus = events.first { segment.start...segment.end ~= $0.t }?.position ?? position
                    if exp(depth.value) < 1.05 {
                        panX.snap(to: focus.x)
                        panY.snap(to: focus.y)
                    }
                } else {
                    let deadZone = 0.5 / targetScale * 0.55
                    focus.x = focus.x.clamped(to: (position.x - deadZone)...(position.x + deadZone))
                    focus.y = focus.y.clamped(to: (position.y - deadZone)...(position.y + deadZone))
                }
            } else {
                activeSegment = nil
            }

            depth.step(toward: log(targetScale), dt: dt)
            panX.step(toward: focus.x, dt: dt)
            panY.step(toward: focus.y, dt: dt)
            states.append(CameraState(scale: max(1, exp(depth.value)), focus: NormPoint(panX.value, panY.value)))
        }
        return CameraPath(fps: fps, states: states)
    }

    private static func clicks(in events: [InputEvent]) -> [ClosedRange<Double>] {
        events.filter { $0.kind == .click }.map { $0.t...$0.t }
    }

    private static func typingBursts(in events: [InputEvent]) -> [ClosedRange<Double>] {
        let keys = events.filter { $0.kind == .key }.map(\.t).sorted()
        var bursts: [[Double]] = []
        for t in keys {
            if let last = bursts.last?.last, t - last <= typingGap {
                bursts[bursts.count - 1].append(t)
            } else {
                bursts.append([t])
            }
        }
        return bursts
            .filter { $0.count >= minTypingKeys }
            .map { $0[0]...$0[$0.count - 1] }
    }
}

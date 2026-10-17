import SwiftUI

struct TimelineScale {
    let width: CGFloat
    let duration: Double

    var pointsPerSecond: CGFloat { duration > 0 ? width / duration : 0 }

    func x(_ time: Double) -> CGFloat {
        CGFloat(time) * pointsPerSecond
    }

    func time(_ x: CGFloat) -> Double {
        pointsPerSecond > 0 ? Double(x / pointsPerSecond).clamped(to: 0...duration) : 0
    }
}

struct EditorTimeline: View {
    static let rulerHeight: CGFloat = 20
    static let clipHeight: CGFloat = 58
    static let zoomHeight: CGFloat = 34
    static let spacing: CGFloat = 8

    let editor: EditorModel

    var body: some View {
        GeometryReader { proxy in
            let scale = TimelineScale(width: proxy.size.width, duration: editor.project.duration)
            VStack(alignment: .leading, spacing: Self.spacing) {
                TimeRuler(scale: scale)
                    .frame(height: Self.rulerHeight)
                    .contentShape(.rect)
                    .gesture(scrub(scale))
                ClipTrack(editor: editor, scale: scale)
                    .frame(height: Self.clipHeight)
                ZoomTrack(editor: editor, scale: scale)
                    .frame(height: Self.zoomHeight)
            }
            .overlay(alignment: .topLeading) {
                Playhead(height: proxy.size.height)
                    .offset(x: scale.x(editor.currentTime) - Playhead.width / 2)
            }
        }
        .frame(height: Self.rulerHeight + Self.clipHeight + Self.zoomHeight + Self.spacing * 2)
    }

    private func scrub(_ scale: TimelineScale) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { editor.seek(to: scale.time($0.location.x)) }
    }
}

private struct TimeRuler: View {
    let scale: TimelineScale

    var body: some View {
        Canvas { context, size in
            let step = tickStep
            for tick in 0...Int(scale.duration / step) {
                let time = Double(tick) * step
                let x = scale.x(time)
                let major = tick.isMultiple(of: 5)
                context.fill(
                    Path(CGRect(x: x, y: size.height - (major ? 7 : 4), width: 1, height: major ? 7 : 4)),
                    with: .color(.white.opacity(major ? 0.3 : 0.15))
                )
                if major {
                    context.draw(
                        Text(time.timecode).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.tertiaryText),
                        at: CGPoint(x: x + 3, y: 0),
                        anchor: .topLeading
                    )
                }
            }
        }
    }

    private var tickStep: Double {
        [0.2, 1, 2, 6, 12, 60].first { scale.x($0) >= 14 } ?? 120
    }
}

private struct Playhead: View {
    static let width: CGFloat = 12
    let height: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 6, bottomTrailingRadius: 6, topTrailingRadius: 3)
                .fill(.white)
                .frame(width: Self.width, height: 14)
            Rectangle()
                .fill(.white)
                .frame(width: 2, height: height - 14)
        }
        .shadow(color: .black.opacity(0.5), radius: 3)
        .allowsHitTesting(false)
    }
}

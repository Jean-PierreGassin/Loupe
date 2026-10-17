import LoupeCore
import SwiftUI

struct ZoomTrack: View {
    let editor: EditorModel
    let scale: TimelineScale

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.035))
                .overlay {
                    if editor.project.zooms.isEmpty {
                        Text("Double-click to add a zoom")
                            .font(.caption)
                            .foregroundStyle(.tertiaryText)
                    }
                }
                .contentShape(.rect)
                .onTapGesture(count: 2) { location in
                    editor.addZoom(at: scale.time(location.x))
                }
                .onTapGesture { editor.selectedZoomID = nil }
            ForEach(editor.project.zooms) { zoom in
                ZoomBlock(editor: editor, zoom: zoom, scale: scale)
            }
        }
        .coordinateSpace(.named(ZoomBlock.space))
    }
}

private struct ZoomBlock: View {
    static let space = "zoomTrack"
    private static let edgeWidth: CGFloat = 8

    let editor: EditorModel
    let zoom: ZoomSegment
    let scale: TimelineScale
    @State private var grabOffset: Double?

    private var isSelected: Bool { editor.selectedZoomID == zoom.id }

    var body: some View {
        let width = max(Self.edgeWidth * 2, scale.x(zoom.end) - scale.x(zoom.start))

        HStack(spacing: 5) {
            Image(systemName: "plus.magnifyingglass")
            if width > 70 {
                Text(zoom.scale, format: .number.precision(.fractionLength(1)))
                    + Text("×")
            }
        }
        .font(.caption)
        .foregroundStyle(.white)
        .lineLimit(1)
        .frame(width: width, height: EditorTimeline.zoomHeight)
        .background(
            LinearGradient(colors: [.brand, .brand.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                .opacity(isSelected ? 1 : 0.55),
            in: .rect(cornerRadius: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(isSelected ? 0.9 : 0.15), lineWidth: isSelected ? 2 : 1))
        .overlay(alignment: .leading) { edge { editor.resizeZoom(zoom.id, start: $0) } }
        .overlay(alignment: .trailing) { edge { editor.resizeZoom(zoom.id, end: $0) } }
        .contentShape(.rect)
        .gesture(move)
        .onTapGesture { editor.selectedZoomID = zoom.id }
        .offset(x: scale.x(zoom.start))
        .animation(.snappy(duration: 0.15), value: isSelected)
    }

    private var move: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named(Self.space))
            .onChanged { value in
                let pointer = scale.time(value.location.x)
                let offset = grabOffset ?? pointer - zoom.start
                grabOffset = offset
                editor.selectedZoomID = zoom.id
                editor.moveZoom(zoom.id, to: pointer - offset)
            }
            .onEnded { _ in grabOffset = nil }
    }

    private func edge(_ resize: @escaping (Double) -> Void) -> some View {
        Color.clear
            .frame(width: Self.edgeWidth)
            .contentShape(.rect)
            .pointerStyle(.columnResize)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        editor.selectedZoomID = zoom.id
                        resize(scale.time(value.location.x))
                    }
            )
    }
}

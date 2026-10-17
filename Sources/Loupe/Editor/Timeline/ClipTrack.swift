import SwiftUI

struct ClipTrack: View {
    let editor: EditorModel
    let scale: TimelineScale

    private static let minimumLength = 0.5
    private static let handleWidth: CGFloat = 12

    var body: some View {
        let start = scale.x(editor.project.trimStart)
        let end = scale.x(editor.project.trimEnd)

        ZStack(alignment: .leading) {
            filmstrip
                .contentShape(.rect)
                .gesture(DragGesture(minimumDistance: 0).onChanged { editor.seek(to: scale.time($0.location.x)) })
            Rectangle()
                .fill(.black.opacity(0.62))
                .frame(width: start)
                .allowsHitTesting(false)
            Rectangle()
                .fill(.black.opacity(0.62))
                .frame(width: max(0, scale.width - end))
                .offset(x: end)
                .allowsHitTesting(false)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.trim, lineWidth: 2)
                .frame(width: max(0, end - start))
                .offset(x: start)
                .allowsHitTesting(false)
            handle(edge: .leading)
                .offset(x: start)
            handle(edge: .trailing)
                .offset(x: end - Self.handleWidth)
        }
        .clipShape(.rect(cornerRadius: 8))
        .coordinateSpace(.named(Self.space))
    }

    private var filmstrip: some View {
        HStack(spacing: 0) {
            ForEach(editor.filmstrip.indices, id: \.self) { index in
                Image(decorative: editor.filmstrip[index], scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: scale.width / CGFloat(max(1, editor.filmstrip.count)))
                    .clipped()
            }
        }
        .frame(width: scale.width, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background(.raised)
    }

    private func handle(edge: HorizontalEdge) -> some View {
        UnevenRoundedRectangle(
            topLeadingRadius: edge == .leading ? 8 : 0,
            bottomLeadingRadius: edge == .leading ? 8 : 0,
            bottomTrailingRadius: edge == .trailing ? 8 : 0,
            topTrailingRadius: edge == .trailing ? 8 : 0
        )
        .fill(.trim)
        .frame(width: Self.handleWidth)
        .overlay {
            Capsule()
                .fill(.black.opacity(0.45))
                .frame(width: 2, height: 16)
        }
        .contentShape(.rect)
        .pointerStyle(.frameResize(position: edge == .leading ? .leading : .trailing))
        .gesture(
            DragGesture(coordinateSpace: .named(ClipTrack.space))
                .onChanged { value in
                    let time = scale.time(value.location.x)
                    if edge == .leading {
                        editor.project.trimStart = max(0, min(time, editor.project.trimEnd - Self.minimumLength))
                        editor.seek(to: editor.project.trimStart)
                    } else {
                        editor.project.trimEnd = min(editor.project.duration, max(time, editor.project.trimStart + Self.minimumLength))
                        editor.seek(to: editor.project.trimEnd)
                    }
                }
        )
    }

    static let space = "clipTrack"
}

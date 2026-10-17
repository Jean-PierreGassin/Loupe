import SwiftUI

struct ControlBarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            RecordGlyph(size: 10, pulsing: true)
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                Text(elapsed(at: context.date))
                    .font(.timecode)
                    .foregroundStyle(.primaryText)
                    .monospacedDigit()
                    .frame(width: 44, alignment: .leading)
            }
            Divider()
                .frame(height: 18)
            Button(action: model.stopRecording) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .frame(width: 30, height: 30)
                    .background(.record.gradient, in: .circle)
            }
            .buttonStyle(.plain)
            .help("Stop and edit (⌥⌘R)")
            Button(action: model.discardRecording) {
                Image(systemName: "trash")
            }
            .buttonStyle(.icon(size: 30))
            .help("Discard recording")
        }
        .padding(.leading, 16)
        .padding(.trailing, 7)
        .frame(height: 44)
        .background(.ultraThinMaterial, in: .capsule)
        .background(.black.opacity(0.35), in: .capsule)
        .overlay(Capsule().strokeBorder(.hairline))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        .padding(16)
        .gesture(WindowDragGesture())
    }

    private func elapsed(at date: Date) -> String {
        guard case let .recording(since) = model.phase else { return "0:00" }
        return date.timeIntervalSince(since).timecode
    }
}

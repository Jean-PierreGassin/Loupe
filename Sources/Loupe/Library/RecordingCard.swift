import SwiftUI

struct RecordingCard: View {
    @Environment(AppModel.self) private var model
    let recording: Recording
    @State private var thumbnail: NSImage?
    @State private var hovering = false

    var body: some View {
        Button { model.open(recording) } label: {
            VStack(alignment: .leading, spacing: 10) {
                preview
                VStack(alignment: .leading, spacing: 3) {
                    Text(recording.project.title)
                        .font(.heading)
                        .foregroundStyle(.primaryText)
                        .lineLimit(1)
                    Text(recording.project.createdAt, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondaryText)
                }
                .padding(.horizontal, 2)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Open") { model.open(recording) }
            Button("Show in Finder") { model.library.reveal(recording) }
            Divider()
            Button("Move to Trash", role: .destructive) { model.library.trash(recording) }
        }
        .task(id: recording.thumbnailURL) {
            if !FileManager.default.fileExists(atPath: recording.thumbnailURL.path()) {
                await RecordingLibrary.writeThumbnail(for: recording)
            }
            thumbnail = NSImage(contentsOf: recording.thumbnailURL)
        }
    }

    private var preview: some View {
        Color.raised
            .aspectRatio(16 / 10, contentMode: .fit)
            .overlay {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
            .overlay {
                Image(systemName: "play.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.black.opacity(0.45), in: .circle)
                    .background(.ultraThinMaterial, in: .circle)
                    .opacity(hovering ? 1 : 0)
                    .scaleEffect(hovering ? 1 : 0.85)
            }
            .overlay(alignment: .topTrailing) {
                Text(recording.project.trimmedDuration.timecode)
                    .font(.timecode)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.6), in: .capsule)
                    .padding(10)
            }
            .clipShape(.rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(hovering ? .brand.opacity(0.8) : .hairline, lineWidth: hovering ? 2 : 1))
            .shadow(color: .black.opacity(hovering ? 0.5 : 0.25), radius: hovering ? 18 : 8, y: hovering ? 10 : 4)
            .scaleEffect(hovering ? 1.015 : 1)
            .animation(.snappy(duration: 0.2), value: hovering)
    }
}

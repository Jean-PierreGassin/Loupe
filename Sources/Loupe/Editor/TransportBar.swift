import SwiftUI

struct TransportBar: View {
    let editor: EditorModel

    var body: some View {
        HStack(spacing: 14) {
            Button(action: editor.togglePlayback) {
                Image(systemName: editor.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 34, height: 34)
                    .background(.white, in: .circle)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .help("Play or pause (Space)")

            HStack(spacing: 6) {
                Text((editor.currentTime - editor.project.trimStart).preciseTimecode)
                    .foregroundStyle(.primaryText)
                Text("/")
                    .foregroundStyle(.tertiaryText)
                Text(editor.project.trimmedDuration.preciseTimecode)
                    .foregroundStyle(.secondaryText)
            }
            .font(.timecode)
            .monospacedDigit()

            Spacer()

            Button { editor.addZoom() } label: {
                Label("Add Zoom", systemImage: "plus.magnifyingglass")
            }
            .buttonStyle(.quiet)
            .help("Add a zoom at the playhead (Z)")
        }
        .frame(height: 44)
    }
}

import SwiftUI

struct LibraryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            header
            if model.library.recordings.isEmpty {
                EmptyLibraryView()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260, maximum: 360), spacing: 22)], spacing: 26) {
                        ForEach(model.library.recordings) { recording in
                            RecordingCard(recording: recording)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(.canvas)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recordings")
                    .font(.display)
                    .foregroundStyle(.primaryText)
                Text(model.library.recordings.count == 1 ? "1 video" : "\(model.library.recordings.count) videos")
                    .font(.label)
                    .foregroundStyle(.secondaryText)
            }
            Spacer()
            NewRecordingButton()
        }
        .padding(.horizontal, 32)
        .padding(.top, 44)
        .padding(.bottom, 24)
    }
}

struct NewRecordingButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button(action: model.beginSetup) {
            HStack(spacing: 8) {
                Circle().fill(.white).frame(width: 8, height: 8)
                Text("New Recording")
                Text(GlobalHotKey.Shortcut.record.symbol).foregroundStyle(.white.opacity(0.6))
            }
        }
        .buttonStyle(.recording)
        .disabled(model.phase != .idle)
    }
}

private struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.brand, .record], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 88, height: 88)
                    .shadow(color: .brand.opacity(0.5), radius: 30)
                Image(systemName: "video.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 6) {
                Text("Record your first video")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primaryText)
                Text("Loupe records your screen, camera and voice,\nthen zooms in on every click and keystroke for you.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondaryText)
            }
            NewRecordingButton()
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 60)
    }
}

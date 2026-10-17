import SwiftUI

struct SetupView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var setup = model.setup

        Panel {
            VStack(alignment: .leading, spacing: 14) {
                header
                VStack(spacing: 0) {
                    SourceRow(icon: "display", title: "Display", value: setup.display?.name ?? "None") {
                        ForEach(setup.displays) { display in
                            Button(display.name) { setup.displayID = display.id }
                        }
                    }
                    Divider().overlay(.hairline)
                    SourceRow(icon: "video.fill", title: "Camera", value: name(of: setup.cameraID, in: setup.cameras, none: "No camera")) {
                        Button("No camera") { setup.cameraID = nil }
                        Divider()
                        ForEach(setup.cameras) { camera in
                            Button(camera.name) { setup.cameraID = camera.id }
                        }
                    }
                    Divider().overlay(.hairline)
                    SourceRow(icon: "mic.fill", title: "Microphone", value: name(of: setup.microphoneID, in: setup.microphones, none: "No microphone")) {
                        Button("No microphone") { setup.microphoneID = nil }
                        Divider()
                        ForEach(setup.microphones) { microphone in
                            Button(microphone.name) { setup.microphoneID = microphone.id }
                        }
                    }
                    Divider().overlay(.hairline)
                    ToggleRow(icon: "speaker.wave.2.fill", title: "System audio", isOn: $setup.systemAudio)
                }
                .background(.white.opacity(0.045), in: .rect(cornerRadius: 12))

                if !setup.missingPermissions.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(setup.missingPermissions) { PermissionRow(permission: $0) }
                    }
                }

                Button(action: model.startRecording) {
                    HStack(spacing: 8) {
                        Circle().fill(.white).frame(width: 9, height: 9)
                        Text("Start Recording")
                        Spacer()
                        Text("⌥⌘R").foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.recording)
                .disabled(!setup.canRecord)
            }
            .padding(16)
            .frame(width: 320)
        }
        .padding(20)
        .onChange(of: setup.cameraID) { model.cameraSelectionChanged() }
        .onChange(of: setup.displayID) { model.displaySelectionChanged() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.5))
                setup.refresh()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            LoupeMark(size: 26)
            Text("New Recording")
                .font(.heading)
                .foregroundStyle(.primaryText)
            Spacer()
            Button(action: model.cancelSetup) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.icon(size: 24))
            .keyboardShortcut(.cancelAction)
        }
    }

    private func name(of id: String?, in devices: [MediaDevice], none: String) -> String {
        devices.first { $0.id == id }?.name ?? none
    }
}

private struct SourceRow<Options: View>: View {
    let icon: String
    let title: String
    let value: String
    @ViewBuilder let options: Options

    var body: some View {
        Menu {
            options
        } label: {
            HStack(spacing: 10) {
                SourceIcon(name: icon)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondaryText)
                    Text(value)
                        .font(.label)
                        .foregroundStyle(.primaryText)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }
}

private struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            SourceIcon(name: icon)
            Text(title)
                .font(.label)
                .foregroundStyle(.primaryText)
            Spacer()
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .tint(.brand)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }
}

private struct SourceIcon: View {
    let name: String

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primaryText)
            .frame(width: 28, height: 28)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: 7))
    }
}

private struct PermissionRow: View {
    let permission: Permission

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: permission == .screen ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(permission == .screen ? .record : .trim)
            VStack(alignment: .leading, spacing: 1) {
                Text(permission.title)
                    .font(.label)
                    .foregroundStyle(.primaryText)
                Text(permission.reason)
                    .font(.caption)
                    .foregroundStyle(.secondaryText)
            }
            Spacer()
            Button("Allow") { Task { await permission.request() } }
                .buttonStyle(.quiet)
        }
        .padding(10)
        .background(.white.opacity(0.045), in: .rect(cornerRadius: 10))
    }
}

struct LoupeMark: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(LinearGradient(colors: [.brand, .record], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .strokeBorder(.white, lineWidth: size * 0.09)
                .frame(width: size * 0.5, height: size * 0.5)
                .offset(x: -size * 0.04, y: -size * 0.04)
            Capsule()
                .fill(.white)
                .frame(width: size * 0.09, height: size * 0.22)
                .rotationEffect(.degrees(-45))
                .offset(x: size * 0.2, y: size * 0.2)
        }
        .frame(width: size, height: size)
    }
}

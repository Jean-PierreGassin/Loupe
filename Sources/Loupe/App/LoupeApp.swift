import SwiftUI

@main struct LoupeApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("Loupe", id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 1080, minHeight: 700)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1320, height: 840)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Recording", action: model.toggleRecording)
                    .keyboardShortcut("r", modifiers: [.option, .command])
            }
        }

        MenuBarExtra {
            MenuBarContent()
                .environment(model)
        } label: {
            Image(systemName: model.phase.isCapturing ? "record.circle.fill" : "record.circle")
        }
    }
}

private struct MenuBarContent: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.phase {
        case .recording:
            Button("Stop Recording", action: model.stopRecording)
            Button("Discard Recording", action: model.discardRecording)
        case .setup, .countdown:
            Button("Start Recording", action: model.startRecording)
            Button("Cancel", action: model.cancelSetup)
        case .idle, .saving:
            Button("New Recording", action: model.beginSetup)
                .disabled(model.phase == .saving)
        }
        Divider()
        Button("Open Loupe") { model.mainWindow.show() }
        Button("Quit Loupe") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

private struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            switch model.route {
            case .library:
                LibraryView()
            case let .editor(id):
                if let recording = model.library.recording(with: id) {
                    EditorView(recording: recording, library: model.library)
                        .id(id)
                } else {
                    LibraryView()
                }
            }
        }
        .alert("Changes weren't saved", isPresented: saveFailurePresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.library.saveFailure ?? "")
        }
        .background(WindowReader { model.mainWindow.window = $0 })
        .onAppear {
            model.mainWindow.reopen = { openWindow(id: "main") }
        }
        .alert("Something went wrong", isPresented: alertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alert ?? "")
        }
    }

    private var alertPresented: Binding<Bool> {
        Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })
    }

    private var saveFailurePresented: Binding<Bool> {
        Binding(get: { model.library.saveFailure != nil }, set: { if !$0 { model.library.saveFailure = nil } })
    }
}

extension AppModel.Phase {
    var isCapturing: Bool {
        switch self {
        case .recording, .countdown: true
        default: false
        }
    }
}

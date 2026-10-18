import SwiftUI

@main struct LoupeApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    private var model: AppModel { delegate.model }

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
            if model.updater.isEnabled {
                CommandGroup(after: .appInfo) {
                    UpdateMenuItem()
                        .environment(model)
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Recording", action: model.toggleRecording)
                    .keyboardShortcut("r", modifiers: [.option, .shift, .command])
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

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.needsSaveBeforeQuit else { return .terminateNow }
        Task {
            await model.saveBeforeQuit()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
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
        if model.updater.isEnabled {
            UpdateMenuItem()
        }
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
        .alert(model.updater.prompt?.title ?? "", isPresented: updatePresented, presenting: model.updater.prompt) { prompt in
            switch prompt {
            case let .available(release, version):
                Button("Install and Relaunch") { model.installUpdate(release) }
                Button("Skip This Version") { model.updater.skip(version) }
                Button("Later", role: .cancel) {}
            case .installed:
                Button("Relaunch Now") { Updater.relaunch() }
                Button("Later", role: .cancel) {}
            case .upToDate, .failed:
                Button("OK", role: .cancel) {}
            }
        } message: { prompt in
            Text(prompt.message)
        }
    }

    private var updatePresented: Binding<Bool> {
        Binding(
            get: { model.updater.prompt != nil && model.phase == .idle && model.alert == nil },
            set: { if !$0 { model.updater.prompt = nil } }
        )
    }

    private var alertPresented: Binding<Bool> {
        Binding(get: { model.alert != nil }, set: { if !$0 { model.alert = nil } })
    }

    private var saveFailurePresented: Binding<Bool> {
        Binding(get: { model.library.saveFailure != nil }, set: { if !$0 { model.library.saveFailure = nil } })
    }
}

private extension Updater.Prompt {
    var title: String {
        switch self {
        case .available: "A new version of Loupe is available"
        case .upToDate: "You're up to date"
        case let .installed(version): "Loupe \(version) is installed"
        case .failed: "Couldn't update Loupe"
        }
    }

    var message: String {
        switch self {
        case let .available(_, version): "Loupe \(version) is ready to install. Your recordings and permissions stay as they are."
        case let .upToDate(version): "Loupe \(version) is the latest version."
        case .installed: "Relaunch to start using it. Relaunching now stops any export in progress."
        case let .failed(reason): reason
        }
    }
}

private struct UpdateMenuItem: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.updater.state {
        case .installed:
            Button("Relaunch to Update", action: model.relaunchForUpdate)
        case .installing:
            Button("Installing Update…") {}
                .disabled(true)
        case .idle, .checking:
            Button("Check for Updates…", action: model.checkForUpdates)
                .disabled(model.updater.state != .idle)
        }
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

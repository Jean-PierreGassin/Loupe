import SwiftUI

struct EditorView: View {
    let recording: Recording
    let library: RecordingLibrary
    @State private var editor: EditorModel?

    var body: some View {
        ZStack {
            Color.canvas
            if let editor {
                EditorWorkspace(editor: editor)
            }
        }
        .task {
            let editor = EditorModel(recording: recording, library: library)
            self.editor = editor
            await editor.load()
        }
    }
}

private struct EditorWorkspace: View {
    @Environment(AppModel.self) private var model
    let editor: EditorModel
    @State private var exporting = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                toolbar
                PreviewStage(editor: editor)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                TransportBar(editor: editor)
                    .padding(.horizontal, 20)
                EditorTimeline(editor: editor)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }
            .background(.canvas)
            Rectangle()
                .fill(.hairline)
                .frame(width: 1)
            InspectorView(editor: editor)
                .frame(width: 300)
                .background(.surface)
        }
        .ignoresSafeArea()
        .editorKeyboardShortcuts(editor)
        .onDisappear { editor.teardown() }
        .sheet(isPresented: $exporting) {
            ExportSheet(editor: editor)
        }
    }

    private var toolbar: some View {
        @Bindable var editor = editor

        return HStack(spacing: 12) {
            Button(action: model.showLibrary) {
                Label("Library", systemImage: "chevron.left")
            }
            .buttonStyle(.quiet)

            TitleField(title: $editor.project.title)
                .frame(maxWidth: 360, alignment: .leading)

            Spacer()

            Button { exporting = true } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.primary)
        }
        .padding(.leading, 84)
        .padding(.trailing, 20)
        .frame(height: 52)
    }
}

private struct EditorKeyboardShortcuts: ViewModifier {
    let editor: EditorModel
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    let handled = MainActor.assumeIsolated { handle(KeyPress(event)) }
                    return handled ? nil : event
                }
            }
            .onDisappear {
                monitor.map(NSEvent.removeMonitor)
                monitor = nil
            }
    }

    private func handle(_ key: KeyPress) -> Bool {
        guard key.isFree else { return false }
        let step = key.shift ? 5.0 : 1.0
        switch key.code {
        case 49: editor.togglePlayback()
        case 51, 117: editor.deleteSelectedZoom()
        case 123: editor.seek(to: editor.currentTime - step)
        case 124: editor.seek(to: editor.currentTime + step)
        case 6: editor.addZoom()
        case 53 where editor.selectedZoomID != nil: editor.selectedZoomID = nil
        default: return false
        }
        return true
    }
}

@MainActor private struct KeyPress {
    let code: UInt16
    let shift: Bool
    let isFree: Bool

    init(_ event: NSEvent) {
        code = event.keyCode
        shift = event.modifierFlags.contains(.shift)
        isFree = event.window.map { !($0 is NSPanel) && $0.attachedSheet == nil && !($0.firstResponder is NSText) } ?? false
    }
}

private extension View {
    func editorKeyboardShortcuts(_ editor: EditorModel) -> some View {
        modifier(EditorKeyboardShortcuts(editor: editor))
    }
}

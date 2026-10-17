import AppKit
import LoupeCore

@MainActor @Observable final class AppModel {
    enum Phase: Equatable {
        case idle
        case setup
        case countdown(Int)
        case recording(since: Date)
        case saving
    }

    enum Route: Hashable {
        case library
        case editor(Recording.ID)
    }

    private(set) var phase = Phase.idle
    var route = Route.library {
        didSet { UserDefaults.standard.set(route.recordingID?.uuidString, forKey: "openRecording") }
    }
    var alert: String?

    let library = RecordingLibrary()
    let setup = CaptureSetup()
    let camera = CameraFeed()

    @ObservationIgnored let mainWindow = MainWindow()
    @ObservationIgnored private lazy var overlays = OverlayController(model: self)
    @ObservationIgnored private var active: (recorder: ScreenRecorder, folder: URL)?
    @ObservationIgnored private var countdown: Task<Void, Never>?
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private var hotKey: GlobalHotKey?

    init() {
        hotKey = GlobalHotKey(.record) { [weak self] in self?.toggleRecording() }
        if let id = UserDefaults.standard.string(forKey: "openRecording").flatMap(UUID.init), library.recording(with: id) != nil {
            route = .editor(id)
        }
        Task { await library.recoverInterruptedRecordings() }
    }

    var needsSaveBeforeQuit: Bool { active != nil || pendingSave != nil }

    func saveBeforeQuit() async {
        stopRecording()
        await pendingSave?.value
    }

    func toggleRecording() {
        switch phase {
        case .idle: beginSetup()
        case .setup: startRecording()
        case .countdown: cancelSetup()
        case .recording: stopRecording()
        case .saving: break
        }
    }

    func beginSetup() {
        guard phase == .idle else { return }
        setup.refresh()
        phase = .setup
        mainWindow.hide()
        overlays.showSetup()
        cameraSelectionChanged()
    }

    func cameraSelectionChanged() {
        camera.use(deviceID: setup.cameraID)
        if setup.cameraID == nil {
            overlays.hideBubble()
        } else {
            overlays.showBubble()
        }
    }

    func bubbleSizeChanged() {
        overlays.keepBubbleOnScreen()
    }

    func displaySelectionChanged() {
        overlays.showSetup()
        if setup.cameraID != nil {
            overlays.showBubble()
        }
    }

    func cancelSetup() {
        countdown?.cancel()
        countdown = nil
        overlays.hideAll()
        camera.stop()
        phase = .idle
        mainWindow.show()
    }

    func startRecording() {
        guard phase == .setup, let display = setup.display, setup.canRecord else { return }
        overlays.hideSetup()
        countdown = Task {
            for remaining in stride(from: 3, through: 1, by: -1) {
                phase = .countdown(remaining)
                overlays.showCountdown()
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
            }
            overlays.hideCountdown()
            await capture(display: display)
        }
    }

    private func capture(display: DisplayOption) async {
        do {
            let folder = try library.makeFolder()
            do {
                let recorder = try await ScreenRecorder.start(.init(
                    displayID: display.id,
                    camera: setup.cameraID == nil ? nil : camera,
                    microphoneID: setup.microphoneID,
                    systemAudio: setup.systemAudio,
                    destination: folder.appending(path: "recording.mov")
                ))
                guard !Task.isCancelled else {
                    await recorder.discard()
                    try? FileManager.default.removeItem(at: folder)
                    return
                }
                recorder.onInterruption = { [weak self] reason in self?.captureInterrupted(reason) }
                active = (recorder, folder)
                phase = .recording(since: .now)
                overlays.showControlBar()
            } catch {
                try? FileManager.default.removeItem(at: folder)
                throw error
            }
        } catch {
            fail(error)
        }
    }

    func stopRecording() {
        guard case .recording = phase, let active else { return }
        phase = .saving
        self.active = nil
        pendingSave = Task {
            defer { pendingSave = nil }
            do {
                let take = try await active.recorder.stop()
                let recording = makeRecording(from: take, in: active.folder)
                await RecordingLibrary.writeThumbnail(for: recording)
                library.save(recording)
                finishSession()
                open(recording)
            } catch {
                try? FileManager.default.removeItem(at: active.folder)
                fail(error)
            }
        }
    }

    private func captureInterrupted(_ reason: String) {
        stopRecording()
        alert = "Recording stopped early. \(reason)"
    }

    func discardRecording() {
        guard case .recording = phase, let active else { return }
        phase = .saving
        self.active = nil
        Task {
            await active.recorder.discard()
            try? FileManager.default.removeItem(at: active.folder)
            finishSession()
            mainWindow.show()
        }
    }

    func open(_ recording: Recording) {
        route = .editor(recording.id)
        mainWindow.show()
    }

    func showLibrary() {
        route = .library
    }

    private func makeRecording(from take: ScreenRecorder.Take, in folder: URL) -> Recording {
        var project = Project(
            title: "Recording " + Date.now.formatted(date: .abbreviated, time: .shortened),
            duration: take.duration,
            screenWidth: Int(take.pixelSize.width),
            screenHeight: Int(take.pixelSize.height),
            hasCamera: take.hasCamera,
            events: take.events,
            cursor: take.cursor
        )
        if let placement = overlays.bubblePlacement {
            project.style.camera.size = placement.size
            project.style.camera.center = project.style.camera.clamped(placement.center, aspect: project.aspect)
        }
        return Recording(folder: folder, project: project)
    }

    private func finishSession() {
        overlays.hideAll()
        camera.stop()
        phase = .idle
    }

    private func fail(_ error: Error) {
        active = nil
        finishSession()
        alert = error.localizedDescription
        mainWindow.show()
    }
}

extension AppModel.Route {
    var recordingID: Recording.ID? {
        if case let .editor(id) = self { id } else { nil }
    }
}

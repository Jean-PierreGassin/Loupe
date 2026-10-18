import AppKit
import AVFoundation
import LoupeCore

@MainActor @Observable final class EditorModel {
    enum ExportState: Equatable {
        case idle
        case exporting(Double)
        case finished(URL)
        case failed(String)
    }

    static let previewWidth = 1600
    static let minimumZoom = 0.6

    private(set) var recording: Recording
    var project: Project {
        didSet { projectDidChange(from: oldValue) }
    }

    let player = AVPlayer()
    private(set) var currentTime = 0.0
    private(set) var isPlaying = false
    private(set) var filmstrip: [CGImage] = []
    private(set) var loadError: String?
    var selectedZoomID: ZoomSegment.ID?
    var exportState = ExportState.idle

    @ObservationIgnored private let library: RecordingLibrary
    @ObservationIgnored private var editable: EditableComposition?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var rebuildTask: Task<Void, Never>?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var exportTask: Task<Void, Never>?
    @ObservationIgnored private var exportID: UUID?
    @ObservationIgnored private var terminationObserver: NSObjectProtocol?

    init(recording: Recording, library: RecordingLibrary) {
        self.recording = recording
        self.library = library
        project = recording.project
    }

    var selectedZoom: ZoomSegment? {
        project.zooms.first { $0.id == selectedZoomID }
    }

    func load() async {
        terminationObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.flush() }
        }
        observePlayback()
        await rebuildComposition()
        await loadFilmstrip()
    }

    func togglePlayback() {
        if isPlaying {
            player.pause()
        } else {
            if currentTime >= project.trimEnd - 0.05 {
                seek(to: project.trimStart)
            }
            player.play()
        }
    }

    func scrub(to time: Double) {
        player.pause()
        seek(to: time)
    }

    func seek(to time: Double) {
        let clamped = time.clamped(to: project.trimStart...project.trimEnd)
        currentTime = clamped
        player.seek(to: CMTime(seconds: clamped - project.trimStart, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    func addZoom(at time: Double? = nil) {
        let start = (time ?? currentTime).clamped(to: 0...max(0, project.duration - 1))
        let zoom = ZoomSegment(start: start, end: min(project.duration, start + 2.5), scale: project.defaultZoomScale, isAuto: false)
        project.zooms.removeAll { $0.overlaps(zoom) }
        project.zooms.append(zoom)
        project.zooms.sort { $0.start < $1.start }
        selectedZoomID = zoom.id
    }

    func deleteSelectedZoom() {
        project.zooms.removeAll { $0.id == selectedZoomID }
        selectedZoomID = nil
    }

    func moveZoom(_ id: ZoomSegment.ID, to start: Double) {
        editZoom(id) { zoom, bounds in
            let duration = zoom.duration
            zoom.start = start.clamped(to: bounds.lowerBound...max(bounds.lowerBound, bounds.upperBound - duration))
            zoom.end = zoom.start + duration
        }
    }

    func resizeZoom(_ id: ZoomSegment.ID, start: Double) {
        editZoom(id) { zoom, bounds in
            zoom.start = start.clamped(to: bounds.lowerBound...max(bounds.lowerBound, zoom.end - Self.minimumZoom))
        }
    }

    func resizeZoom(_ id: ZoomSegment.ID, end: Double) {
        editZoom(id) { zoom, bounds in
            zoom.end = end.clamped(to: min(bounds.upperBound, zoom.start + Self.minimumZoom)...bounds.upperBound)
        }
    }

    func setZoomScale(_ id: ZoomSegment.ID, _ scale: Double) {
        editZoom(id) { zoom, _ in zoom.scale = scale }
    }

    private func editZoom(_ id: ZoomSegment.ID, _ change: (inout ZoomSegment, ClosedRange<Double>) -> Void) {
        guard let index = project.zooms.firstIndex(where: { $0.id == id }) else { return }
        let original = project.zooms[index]
        let others = project.zooms.filter { $0.id != id }
        let lower = others.filter { $0.end <= original.start + 0.001 }.map(\.end).max() ?? 0
        let upper = others.filter { $0.start >= original.end - 0.001 }.map(\.start).min() ?? project.duration
        var zoom = original
        change(&zoom, lower...upper)
        zoom.isAuto = false
        project.zooms[index] = zoom
    }

    func setAutoZoom(_ enabled: Bool) {
        project.autoZoom = enabled
        project.replanAutoZooms()
    }

    func setDefaultZoomScale(_ scale: Double) {
        project.defaultZoomScale = scale
        for index in project.zooms.indices where project.zooms[index].isAuto {
            project.zooms[index].scale = scale
        }
    }

    func pause() {
        player.pause()
    }

    func startExport(quality: ExportQuality) {
        exportTask = Task { await export(quality: quality) }
    }

    func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        exportID = nil
        exportState = .idle
    }

    private func export(quality: ExportQuality) async {
        player.pause()
        library.exportsInProgress += 1
        defer { library.exportsInProgress -= 1 }
        let id = UUID()
        exportID = id
        exportState = .exporting(0)
        let scratch = URL.temporaryDirectory.appending(path: "Loupe-\(id.uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: scratch) }
        do {
            try await Exporter.export(recording: recording.videoURL, project: project, quality: quality, to: scratch) { [weak self] progress in
                Task { @MainActor in
                    guard let self, self.exportID == id else { return }
                    self.exportState = .exporting(progress)
                }
            }
            try Task.checkCancellation()
            try FileManager.default.createDirectory(at: library.exportsFolder, withIntermediateDirectories: true)
            let destination = library.exportDestination(for: project.title)
            try FileManager.default.moveItem(at: scratch, to: destination)
            exportState = .finished(destination)
        } catch {
            guard exportID == id, !Task.isCancelled else { return }
            exportState = .failed(error.localizedDescription)
        }
    }

    func teardown() {
        terminationObserver.map(NotificationCenter.default.removeObserver)
        terminationObserver = nil
        player.pause()
        timeObserver.map(player.removeTimeObserver)
        timeObserver = nil
        statusObservation = nil
        saveTask?.cancel()
        save()
        let recording = recording
        Task.detached { await RecordingLibrary.writeThumbnail(for: recording) }
    }

    private func projectDidChange(from old: Project) {
        recording.project = project
        scheduleSave()
        if old.trimStart != project.trimStart || old.trimEnd != project.trimEnd {
            scheduleRebuild()
        } else if old.zooms != project.zooms || old.style != project.style || old.hasCamera != project.hasCamera {
            refreshPreview()
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    private func flush() {
        saveTask?.cancel()
        save()
        cancelExport()
    }

    private func save() {
        library.save(recording)
    }

    private func scheduleRebuild() {
        rebuildTask?.cancel()
        rebuildTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await rebuildComposition()
        }
    }

    private func rebuildComposition() async {
        do {
            let editable = try await EditableComposition(recording: recording.videoURL, project: project)
            self.editable = editable
            let item = AVPlayerItem(asset: editable.asset)
            item.videoComposition = editable.videoComposition(for: project, width: Self.previewWidth)
            player.replaceCurrentItem(with: item)
            seek(to: currentTime)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func refreshPreview() {
        guard let editable, let item = player.currentItem else { return }
        item.videoComposition = editable.videoComposition(for: project, width: Self.previewWidth)
        if !isPlaying {
            seek(to: currentTime)
        }
    }

    private func observePlayback() {
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 60), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, self.player.rate != 0 else { return }
                self.currentTime = (time.seconds + self.project.trimStart).clamped(to: self.project.trimStart...self.project.trimEnd)
            }
        }
        statusObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            let playing = player.timeControlStatus != .paused
            Task { @MainActor in self?.isPlaying = playing }
        }
    }

    private func loadFilmstrip() async {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: recording.videoURL))
        generator.maximumSize = CGSize(width: 320, height: 200)
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity
        let count = 14
        let times = (0..<count).map { CMTime(seconds: project.duration * (Double($0) + 0.5) / Double(count), preferredTimescale: 600) }
        var frames: [CGImage] = []
        for await result in generator.images(for: times) {
            if let image = try? result.image {
                frames.append(image)
            }
        }
        filmstrip = frames
    }
}

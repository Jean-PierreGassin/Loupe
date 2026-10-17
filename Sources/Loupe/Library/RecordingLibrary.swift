import AppKit
import AVFoundation
import LoupeCore

struct Recording: Identifiable, Hashable {
    let folder: URL
    var project: Project

    var id: UUID { project.id }
    var videoURL: URL { folder.appending(path: "recording.mov") }
    var thumbnailURL: URL { folder.appending(path: "thumbnail.jpg") }
    fileprivate var projectURL: URL { folder.appending(path: "project.json") }
}

@MainActor @Observable final class RecordingLibrary {
    private(set) var recordings: [Recording] = []
    var saveFailure: String?

    let root = ProcessInfo.processInfo.environment["LOUPE_LIBRARY"].map { URL(filePath: $0) }
        ?? URL.moviesDirectory.appending(path: "Loupe")
    var exportsFolder: URL { root.appending(path: "Exports") }

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init() {
        reload()
    }

    func reload() {
        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        recordings = folders
            .compactMap { folder in
                let url = folder.appending(path: "project.json")
                guard let data = try? Data(contentsOf: url), let project = try? decoder.decode(Project.self, from: data) else { return nil }
                return Recording(folder: folder, project: project)
            }
            .sorted { $0.project.createdAt > $1.project.createdAt }
    }

    func recoverInterruptedRecordings() async {
        let manager = FileManager.default
        let folders = ((try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []).filter { folder in
            manager.fileExists(atPath: folder.appending(path: "recording.mov").path())
                && !manager.fileExists(atPath: folder.appending(path: "project.json").path())
        }
        for folder in folders {
            guard let project = await Self.recoveredProject(from: folder.appending(path: "recording.mov")) else { continue }
            let recording = Recording(folder: folder, project: project)
            await Self.writeThumbnail(for: recording)
            save(recording)
        }
    }

    func recording(with id: Recording.ID) -> Recording? {
        recordings.first { $0.id == id }
    }

    func makeFolder() throws -> URL {
        let folder = root.appending(path: Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false).timeSeparator(.omitted)))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func save(_ recording: Recording) {
        do {
            try encoder.encode(recording.project).write(to: recording.projectURL, options: .atomic)
            saveFailure = nil
        } catch {
            saveFailure = "“\(recording.project.title)” couldn't be saved. \(error.localizedDescription)"
        }
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index] = recording
        } else {
            recordings.insert(recording, at: 0)
        }
    }

    func trash(_ recording: Recording) {
        try? FileManager.default.trashItem(at: recording.folder, resultingItemURL: nil)
        recordings.removeAll { $0.id == recording.id }
    }

    func exportDestination(for title: String) -> URL {
        let cleaned = title
            .components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        let base = cleaned.isEmpty ? "Untitled" : cleaned
        return (1...).lazy
            .map { self.exportsFolder.appending(path: $0 == 1 ? "\(base).mp4" : "\(base) \($0).mp4") }
            .first { !FileManager.default.fileExists(atPath: $0.path()) }!
    }

    func reveal(_ recording: Recording) {
        NSWorkspace.shared.activateFileViewerSelecting([recording.videoURL])
    }

    nonisolated private static func recoveredProject(from url: URL) async -> Project? {
        let asset = AVURLAsset(url: url)
        guard
            let duration = try? await asset.load(.duration).seconds, duration > 0,
            let tracks = try? await asset.loadTracks(withMediaType: .video).sorted(by: { $0.trackID < $1.trackID }),
            let screen = tracks.first,
            let size = try? await screen.load(.naturalSize)
        else { return nil }
        let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .now
        return Project(
            title: "Recovered " + created.formatted(date: .abbreviated, time: .shortened),
            createdAt: created,
            duration: duration,
            screenWidth: Int(size.width),
            screenHeight: Int(size.height),
            hasCamera: tracks.count > 1,
            events: [],
            cursor: []
        )
    }

    nonisolated static func writeThumbnail(for recording: Recording) async {
        guard let editable = try? await EditableComposition(recording: recording.videoURL, project: recording.project) else { return }
        let generator = AVAssetImageGenerator(asset: editable.asset)
        generator.videoComposition = editable.videoComposition(for: recording.project, width: 800)
        let time = CMTime(seconds: min(1, recording.project.trimmedDuration / 2), preferredTimescale: 600)
        guard
            let image = try? await generator.image(at: time).image,
            let data = NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        else { return }
        try? data.write(to: recording.thumbnailURL, options: .atomic)
    }
}

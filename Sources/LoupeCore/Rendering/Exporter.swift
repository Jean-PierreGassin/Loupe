import AVFoundation

public enum ExportQuality: Int, CaseIterable, Identifiable, Sendable {
    case hd = 1920
    case qhd = 2560
    case uhd = 3840

    public var id: Self { self }

    public var name: String {
        switch self {
        case .hd: "1080p"
        case .qhd: "1440p"
        case .uhd: "4K"
        }
    }
}

public enum Exporter {
    public static func export(
        recording: URL,
        project: Project,
        quality: ExportQuality,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let mixdown = FileManager.default.temporaryDirectory.appending(path: "Loupe-\(UUID().uuidString).m4a")
        defer { try? FileManager.default.removeItem(at: mixdown) }
        let editable = try await EditableComposition(recording: recording, project: project, mixingAudioTo: mixdown)
        guard let session = AVAssetExportSession(asset: editable.asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw LoupeError.exportUnavailable
        }
        session.videoComposition = editable.videoComposition(for: project, width: quality.rawValue)
        session.shouldOptimizeForNetworkUse = true
        try? FileManager.default.removeItem(at: destination)

        let states = session.states(updateInterval: 0.1)
        let monitor = Task {
            for await case let .exporting(state) in states {
                progress(state.fractionCompleted)
            }
        }
        defer { monitor.cancel() }
        try await session.export(to: destination, as: .mp4)
        progress(1)
    }
}

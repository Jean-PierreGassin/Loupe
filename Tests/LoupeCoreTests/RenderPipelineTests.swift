import AVFoundation
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import LoupeCore

@Suite(.serialized) struct RenderPipelineTests {
    let directory = FileManager.default.temporaryDirectory.appending(path: "LoupeTests-\(UUID().uuidString)")

    var project: Project {
        let button = NormPoint(1210 / 1440, 188 / 900)
        var project = Project(
            title: "Synthetic",
            duration: 4,
            screenWidth: 1440,
            screenHeight: 900,
            hasCamera: true,
            events: [InputEvent(t: 1.2, kind: .click, position: button)],
            cursor: [CursorSample(t: 0, position: NormPoint(0.3, 0.6)), CursorSample(t: 1.1, position: button)]
        )
        project.style.camera.center = project.style.camera.center(for: .bottomLeft, aspect: project.aspect)
        return project
    }

    @Test func exportsStyledVideoAtRequestedSize() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let recording = directory.appending(path: "recording.mov")
        let output = directory.appending(path: "export.mp4")
        try await SyntheticRecording.write(to: recording, duration: 4)

        try await Exporter.export(recording: recording, project: project, quality: .hd, to: output) { _ in }

        let asset = AVURLAsset(url: output)
        let duration = try await asset.load(.duration).seconds
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let size = try await track.load(.naturalSize)
        #expect(abs(duration - 4) < 0.2)
        #expect(size == CGSize(width: 1920, height: 1200))
        try await saveFrames(of: asset, at: [0.3, 1.0, 1.4, 2.4, 3.9])
    }

    @Test func trimmingShortensTheExport() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let recording = directory.appending(path: "recording.mov")
        let output = directory.appending(path: "trimmed.mp4")
        try await SyntheticRecording.write(to: recording, duration: 4)
        var trimmed = project
        trimmed.trimStart = 1
        trimmed.trimEnd = 3

        try await Exporter.export(recording: recording, project: trimmed, quality: .hd, to: output) { _ in }

        #expect(abs(try await AVURLAsset(url: output).load(.duration).seconds - 2) < 0.2)
    }

    @Test func stillScreenAtTheEndStillExports() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let recording = directory.appending(path: "still.mov")
        let output = directory.appending(path: "still.mp4")
        try await SyntheticRecording.write(to: recording, duration: 4, screenDuration: 2)

        try await Exporter.export(recording: recording, project: project, quality: .hd, to: output) { _ in }

        #expect(abs(try await AVURLAsset(url: output).load(.duration).seconds - 4) < 0.2)
    }

    private func saveFrames(of asset: AVAsset, at times: [Double]) async throws {
        guard let folder = ProcessInfo.processInfo.environment["LOUPE_FRAMES_DIR"].map(URL.init(fileURLWithPath:)) else { return }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        for time in times {
            let (image, _) = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600))
            let url = folder.appending(path: String(format: "frame-%.1f.png", time)) as CFURL
            let destination = try #require(CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            CGImageDestinationFinalize(destination)
        }
    }
}

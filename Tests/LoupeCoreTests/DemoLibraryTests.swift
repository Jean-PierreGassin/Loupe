import Foundation
import Testing
@testable import LoupeCore

@Suite struct DemoLibraryTests {
    static let destination = ProcessInfo.processInfo.environment["LOUPE_SEED_LIBRARY"]

    @Test(.enabled(if: destination != nil)) func seedsDemoRecording() async throws {
        let folder = URL(filePath: try #require(Self.destination)).appending(path: "demo")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try await SyntheticRecording.write(to: folder.appending(path: "recording.mov"), duration: 12)

        let button = NormPoint(1210 / 1440, 188 / 900)
        let row = NormPoint(0.35, 0.42)
        let typing = stride(from: 6.0, to: 8.4, by: 0.15).map { time in
            InputEvent(t: time, kind: .key, position: NormPoint((330 + 390 * (time - 6) / 2.4) / 1440, 374 / 900))
        }
        var project = Project(
            title: "Publishing the Q3 launch",
            duration: 12,
            screenWidth: 1440,
            screenHeight: 900,
            hasCamera: true,
            events: [InputEvent(t: 2, kind: .click, position: button), InputEvent(t: 5.6, kind: .click, position: row)] + typing,
            cursor: [
                CursorSample(t: 0, position: NormPoint(0.3, 0.7)),
                CursorSample(t: 1.8, position: button),
                CursorSample(t: 5.4, position: row),
            ]
        )
        project.style.camera.center = project.style.camera.center(for: .bottomRight, aspect: project.aspect)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(project).write(to: folder.appending(path: "project.json"))

        let exports = URL(filePath: try #require(Self.destination)).appending(path: "Exports")
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        try await Exporter.export(recording: folder.appending(path: "recording.mov"), project: project, quality: .hd, to: exports.appending(path: "demo.mp4")) { _ in }
    }
}

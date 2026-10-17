import Foundation
import LoupeCore
import Testing
@testable import Loupe

@MainActor @Suite final class RecordingLibraryTests {
    let root = URL.temporaryDirectory.appending(path: "LoupeLibrary-\(UUID().uuidString)")

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    @Test func exportNamesAreSafeAndUnique() throws {
        let library = RecordingLibrary(root: root)
        try FileManager.default.createDirectory(at: library.exportsFolder, withIntermediateDirectories: true)

        #expect(library.exportDestination(for: "Q3: launch/plan?").lastPathComponent == "Q3- launch-plan-.mp4")
        #expect(library.exportDestination(for: " .. ").lastPathComponent == "Untitled.mp4")

        FileManager.default.createFile(atPath: library.exportDestination(for: "Demo").path(), contents: Data())
        #expect(library.exportDestination(for: "Demo").lastPathComponent == "Demo 2.mp4")
    }

    @Test func savedRecordingsReloadNewestFirst() throws {
        let library = RecordingLibrary(root: root)
        let older = Recording(folder: root.appending(path: "older"), project: project("Older", age: 60))
        let newer = Recording(folder: root.appending(path: "newer"), project: project("Newer", age: 0))
        for recording in [older, newer] {
            try FileManager.default.createDirectory(at: recording.folder, withIntermediateDirectories: true)
            library.save(recording)
        }

        let reloaded = RecordingLibrary(root: root)

        #expect(reloaded.recordings.map(\.project.title) == ["Newer", "Older"])
        #expect(library.saveFailure == nil)
    }

    @Test func reportsFailedSaves() {
        let library = RecordingLibrary(root: root)
        let missing = Recording(folder: root.appending(path: "missing"), project: project("Lost", age: 0))

        library.save(missing)

        #expect(library.saveFailure?.contains("Lost") == true)
    }

    private func project(_ title: String, age: TimeInterval) -> Project {
        Project(title: title, createdAt: .now - age, duration: 4, screenWidth: 1440, screenHeight: 900, hasCamera: false, events: [], cursor: [])
    }
}

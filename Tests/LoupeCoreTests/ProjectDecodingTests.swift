import Foundation
import Testing
@testable import LoupeCore

@Suite struct ProjectDecodingTests {
    @Test func decodesProjectsMissingNewerFields() throws {
        let json = """
        {
          "id": "6F9619FF-8B86-D011-B42D-00C04FC964FF",
          "duration": 12.5,
          "screenWidth": 2880,
          "screenHeight": 1800,
          "style": { "background": "ocean", "camera": { "size": 0.3, "shape": "hexagon" } }
        }
        """
        let project = try JSONDecoder().decode(Project.self, from: Data(json.utf8))

        #expect(project.trimEnd == 12.5)
        #expect(project.autoZoom)
        #expect(project.style.background == .ocean)
        #expect(project.style.padding == Style().padding)
        #expect(project.style.camera.size == 0.3)
        #expect(project.style.camera.shape == .circle)
    }

    @Test func dropsOnlyTheElementsItCannotRead() throws {
        let json = """
        {
          "id": "6F9619FF-8B86-D011-B42D-00C04FC964FF",
          "duration": 4,
          "screenWidth": 1440,
          "screenHeight": 900,
          "events": [
            { "t": 1, "kind": "click", "position": { "x": 0.5, "y": 0.5 } },
            { "t": 2, "kind": "scroll", "position": { "x": 0.5, "y": 0.5 } },
            { "t": 3, "kind": "key", "position": { "x": 0.2, "y": 0.4 } }
          ]
        }
        """
        let project = try JSONDecoder().decode(Project.self, from: Data(json.utf8))

        #expect(project.events.map(\.t) == [1, 3])
    }

    @Test func roundTripsEveryField() throws {
        var project = Project(
            title: "Round trip",
            duration: 8,
            screenWidth: 1440,
            screenHeight: 900,
            hasCamera: true,
            events: [InputEvent(t: 1, kind: .click, position: .center)],
            cursor: [CursorSample(t: 0, position: .center)]
        )
        project.trimStart = 1
        project.style.background = .mint
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(Project.self, from: encoder.encode(project))

        #expect(decoded.id == project.id)
        #expect(decoded.zooms == project.zooms)
        #expect(decoded.style == project.style)
        #expect(decoded.trimStart == 1)
    }
}

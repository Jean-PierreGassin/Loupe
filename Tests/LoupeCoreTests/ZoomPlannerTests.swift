import Testing
@testable import LoupeCore

@Suite struct ZoomPlannerTests {
    let corner = NormPoint(0.8, 0.2)

    @Test func clickProducesZoomAroundIt() throws {
        let segments = ZoomPlanner.segments(for: [InputEvent(t: 3, kind: .click, position: corner)], duration: 10, scale: 2)

        let segment = try #require(segments.first)
        #expect(segments.count == 1)
        #expect(segment.start < 3 && segment.end > 3)
        #expect(segment.scale == 2)
    }

    @Test func nearbyActivityMergesIntoOneZoom() {
        let events = [1.0, 2.0, 3.5].map { InputEvent(t: $0, kind: .click, position: corner) }

        #expect(ZoomPlanner.segments(for: events, duration: 10, scale: 2).count == 1)
    }

    @Test func distantActivityGetsSeparateZooms() {
        let events = [1.0, 8.0].map { InputEvent(t: $0, kind: .click, position: corner) }

        #expect(ZoomPlanner.segments(for: events, duration: 12, scale: 2).count == 2)
    }

    @Test func typingBurstZoomsButShortcutsDoNot() {
        let shortcut = [1.0, 1.1].map { InputEvent(t: $0, kind: .key, position: corner) }
        let typing = stride(from: 5.0, to: 7.0, by: 0.2).map { InputEvent(t: $0, kind: .key, position: corner) }

        let segments = ZoomPlanner.segments(for: shortcut + typing, duration: 12, scale: 2)

        #expect(segments.count == 1)
        #expect(segments.first.map { $0.start > 4 } == true)
    }

    @Test func cameraSettlesOnClickThenReturns() {
        let click = InputEvent(t: 2, kind: .click, position: corner)
        let segments = ZoomPlanner.segments(for: [click], duration: 10, scale: 2)
        let path = ZoomPlanner.cameraPath(
            segments: segments,
            events: [click],
            cursor: [CursorSample(t: 0, position: corner)],
            duration: 10
        )

        let zoomed = path.state(at: 3)
        #expect(abs(zoomed.scale - 2) < 0.1)
        #expect(abs(zoomed.focus.x - corner.x) < 0.05)
        #expect(abs(path.state(at: 9.5).scale - 1) < 0.02)
        #expect(path.state(at: 0.5).scale == 1)
    }

    @Test func typingZoomFollowsTheCaretNotThePointer() {
        let caret = NormPoint(0.3, 0.7)
        let typing = stride(from: 2.0, to: 4.0, by: 0.15).map { InputEvent(t: $0, kind: .key, position: caret) }
        let path = ZoomPlanner.cameraPath(
            segments: ZoomPlanner.segments(for: typing, duration: 10, scale: 2),
            events: typing,
            cursor: [CursorSample(t: 0, position: corner)],
            duration: 10
        )

        let focus = path.state(at: 3.5).focus
        #expect(abs(focus.x - caret.x) < 0.05)
        #expect(abs(focus.y - caret.y) < 0.05)
    }

    @Test func cameraFollowsThePointerOnceItLeavesTheClick() {
        let click = InputEvent(t: 2, kind: .click, position: corner)
        let away = NormPoint(0.2, 0.8)
        let path = ZoomPlanner.cameraPath(
            segments: [ZoomSegment(start: 1.5, end: 6, scale: 2, isAuto: true)],
            events: [click],
            cursor: [CursorSample(t: 0, position: corner), CursorSample(t: 2.5, position: corner), CursorSample(t: 3, position: away)],
            duration: 8
        )

        #expect(abs(path.state(at: 2.4).focus.x - corner.x) < 0.05)
        #expect(path.state(at: 5).focus.x < 0.5)
    }

    @Test func manualZoomsSurviveReplanning() {
        var project = Project(
            title: "Demo",
            duration: 10,
            screenWidth: 1440,
            screenHeight: 900,
            hasCamera: false,
            events: [InputEvent(t: 2, kind: .click, position: corner)],
            cursor: []
        )
        project.zooms.append(ZoomSegment(start: 6, end: 8, scale: 3, isAuto: false))

        project.autoZoom = false
        project.replanAutoZooms()

        #expect(project.zooms.map(\.isAuto) == [false])
    }
}

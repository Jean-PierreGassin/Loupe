import CoreGraphics
import Testing
@testable import Loupe

@Suite struct InputTrackerTests {
    @Test func skippedKeystrokesTakeTheNextResolvedCaret() {
        let caret = CGPoint(x: 400, y: 300)
        let keys = [
            InputTracker.KeyMark(time: 1, pointer: .zero),
            InputTracker.KeyMark(time: 2, pointer: .zero),
            InputTracker.KeyMark(time: 3, pointer: .zero, focus: caret, resolved: true),
        ]

        #expect(InputTracker.locate(keys).map(\.location) == [caret, caret, caret])
    }

    @Test func keystrokesWithoutACaretUseTheirOwnPointer() {
        let first = CGPoint(x: 5, y: 5)
        let second = CGPoint(x: 10, y: 20)
        let keys = [
            InputTracker.KeyMark(time: 1, pointer: first),
            InputTracker.KeyMark(time: 2, pointer: second, resolved: true),
        ]

        #expect(InputTracker.locate(keys).map(\.location) == [first, second])
    }
}

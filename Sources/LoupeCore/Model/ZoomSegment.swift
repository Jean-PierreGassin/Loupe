import Foundation

public struct ZoomSegment: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var start: Double
    public var end: Double
    public var scale: Double
    public var isAuto: Bool

    public init(id: UUID = UUID(), start: Double, end: Double, scale: Double, isAuto: Bool) {
        self.id = id
        self.start = start
        self.end = end
        self.scale = scale
        self.isAuto = isAuto
    }

    public var duration: Double { end - start }

    public func overlaps(_ other: ZoomSegment) -> Bool {
        start < other.end && other.start < end
    }
}

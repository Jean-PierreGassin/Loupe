import Foundation

public struct Project: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var duration: Double
    public var screenWidth: Int
    public var screenHeight: Int
    public var hasCamera: Bool
    public var events: [InputEvent]
    public var cursor: [CursorSample]
    public var zooms: [ZoomSegment]
    public var autoZoom = true
    public var defaultZoomScale: Double
    public var trimStart = 0.0
    public var trimEnd: Double
    public var style: Style

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        duration: Double,
        screenWidth: Int,
        screenHeight: Int,
        hasCamera: Bool,
        events: [InputEvent],
        cursor: [CursorSample],
        style: Style = Style(),
        defaultZoomScale: Double = 2
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.hasCamera = hasCamera
        self.events = events
        self.cursor = cursor
        self.style = style
        self.defaultZoomScale = defaultZoomScale
        trimEnd = duration
        zooms = ZoomPlanner.segments(for: events, duration: duration, scale: defaultZoomScale)
    }

    public var aspect: Double {
        screenHeight > 0 ? Double(screenWidth) / Double(screenHeight) : 16 / 10
    }

    public var trimmedDuration: Double { max(0, trimEnd - trimStart) }

    public mutating func replanAutoZooms() {
        let manual = zooms.filter { !$0.isAuto }
        let planned = autoZoom ? ZoomPlanner.segments(for: events, duration: duration, scale: defaultZoomScale) : []
        let auto = planned.filter { segment in !manual.contains { $0.overlaps(segment) } }
        zooms = (manual + auto).sorted { $0.start < $1.start }
    }
}

extension Project {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        duration = try container.decode(Double.self, forKey: .duration)
        screenWidth = try container.decode(Int.self, forKey: .screenWidth)
        screenHeight = try container.decode(Int.self, forKey: .screenHeight)
        title = container.decode(.title, default: "Untitled")
        createdAt = container.decode(.createdAt, default: .now)
        hasCamera = container.decode(.hasCamera, default: false)
        events = container.decode(.events, default: [])
        cursor = container.decode(.cursor, default: [])
        zooms = container.decode(.zooms, default: [])
        autoZoom = container.decode(.autoZoom, default: true)
        defaultZoomScale = container.decode(.defaultZoomScale, default: 2)
        trimStart = container.decode(.trimStart, default: 0)
        trimEnd = container.decode(.trimEnd, default: duration)
        style = container.decode(.style, default: Style())
    }
}

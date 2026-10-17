public struct Style: Codable, Hashable, Sendable {
    public var background: BackgroundPreset = .midnight
    public var padding = 0.06
    public var cornerRadius = 0.02
    public var shadow = true
    public var clickHighlights = true
    public var camera = CameraStyle()

    public init() {}

    public var hasBackground: Bool { background != .none }
}

public struct CameraStyle: Codable, Hashable, Sendable {
    public enum Shape: String, Codable, CaseIterable, Sendable {
        case circle
        case rounded
    }

    public enum Corner: CaseIterable, Sendable {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }

    public var visible = true
    public var shape = Shape.circle
    public var size = 0.24
    public var center = NormPoint(0.12, 0.8)
    public var mirror = true

    public init() {}

    public func center(for corner: Corner, aspect: Double) -> NormPoint {
        let margin = 0.04
        let horizontal = margin / aspect + size / 2 / aspect
        let vertical = margin + size / 2
        return switch corner {
        case .topLeft: NormPoint(horizontal, vertical)
        case .topRight: NormPoint(1 - horizontal, vertical)
        case .bottomLeft: NormPoint(horizontal, 1 - vertical)
        case .bottomRight: NormPoint(1 - horizontal, 1 - vertical)
        }
    }

    public func clamped(_ point: NormPoint, aspect: Double) -> NormPoint {
        let halfWidth = size / 2 / aspect
        let halfHeight = size / 2
        return NormPoint(
            point.x.clamped(to: halfWidth...(1 - halfWidth)),
            point.y.clamped(to: halfHeight...(1 - halfHeight))
        )
    }
}

public enum BackgroundPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case midnight
    case aurora
    case sunset
    case ocean
    case mint
    case graphite
    case paper

    public var id: Self { self }

    public var name: String { rawValue.capitalized }

    public var gradient: (start: RGBA, end: RGBA) {
        switch self {
        case .none: (RGBA(0x000000), RGBA(0x000000))
        case .midnight: (RGBA(0x312E81), RGBA(0x0F172A))
        case .aurora: (RGBA(0x7C3AED), RGBA(0xDB2777))
        case .sunset: (RGBA(0xF97316), RGBA(0xBE185D))
        case .ocean: (RGBA(0x0EA5E9), RGBA(0x4338CA))
        case .mint: (RGBA(0x34D399), RGBA(0x0E7490))
        case .graphite: (RGBA(0x3F3F46), RGBA(0x09090B))
        case .paper: (RGBA(0xFAFAF9), RGBA(0xD6D3D1))
        }
    }
}

public struct RGBA: Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(_ hex: UInt32, alpha: Double = 1) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
        self.alpha = alpha
    }
}

extension Comparable {
    public func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

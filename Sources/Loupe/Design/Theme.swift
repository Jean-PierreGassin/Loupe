import SwiftUI

extension ShapeStyle where Self == Color {
    static var canvas: Color { Color(red: 0.055, green: 0.055, blue: 0.07) }
    static var surface: Color { Color(red: 0.085, green: 0.085, blue: 0.105) }
    static var raised: Color { Color(red: 0.12, green: 0.12, blue: 0.145) }
    static var hairline: Color { .white.opacity(0.08) }
    static var primaryText: Color { .white.opacity(0.92) }
    static var secondaryText: Color { .white.opacity(0.55) }
    static var tertiaryText: Color { .white.opacity(0.32) }
    static var brand: Color { Color(red: 0.55, green: 0.42, blue: 1.0) }
    static var record: Color { Color(red: 1.0, green: 0.27, blue: 0.33) }
    static var trim: Color { Color(red: 1.0, green: 0.78, blue: 0.25) }
}

extension Font {
    static let display = Font.system(size: 26, weight: .semibold, design: .rounded)
    static let heading = Font.system(size: 13, weight: .semibold)
    static let label = Font.system(size: 12, weight: .medium)
    static let caption = Font.system(size: 11, weight: .medium)
    static let timecode = Font.system(size: 12, weight: .medium, design: .monospaced)
}

extension Duration {
    var timecode: String {
        let seconds = Int(components.seconds)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

extension Double {
    var timecode: String { Duration.seconds(self).timecode }

    var preciseTimecode: String {
        let tenths = Int((self * 10).rounded(.down)) % 10
        return "\(timecode).\(tenths)"
    }
}

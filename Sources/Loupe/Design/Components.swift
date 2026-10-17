import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = .brand

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.label)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(tint.gradient, in: .rect(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.18)))
            .shadow(color: tint.opacity(0.35), radius: configuration.isPressed ? 2 : 8, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        QuietButton(configuration: configuration)
    }

    private struct QuietButton: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.label)
                .foregroundStyle(.primaryText)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(.white.opacity(configuration.isPressed ? 0.14 : hovering ? 0.09 : 0.05), in: .rect(cornerRadius: 8))
                .onHover { hovering = $0 }
        }
    }
}

struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 28

    func makeBody(configuration: Configuration) -> some View {
        IconButton(configuration: configuration, size: size)
    }

    private struct IconButton: View {
        let configuration: Configuration
        let size: CGFloat
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(hovering ? .primaryText : .secondaryText)
                .frame(width: size, height: size)
                .background(.white.opacity(configuration.isPressed ? 0.14 : hovering ? 0.08 : 0), in: .circle)
                .onHover { hovering = $0 }
        }
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var recording: PrimaryButtonStyle { PrimaryButtonStyle(tint: .record) }
}

extension ButtonStyle where Self == QuietButtonStyle {
    static var quiet: QuietButtonStyle { QuietButtonStyle() }
}

extension ButtonStyle where Self == IconButtonStyle {
    static var icon: IconButtonStyle { IconButtonStyle() }
    static func icon(size: CGFloat) -> IconButtonStyle { IconButtonStyle(size: size) }
}

struct RecordGlyph: View {
    var size: CGFloat = 10
    var pulsing = false

    var body: some View {
        Circle()
            .fill(.record)
            .frame(width: size, height: size)
            .shadow(color: .record.opacity(0.8), radius: pulsing ? 5 : 0)
            .phaseAnimator([false, true], trigger: pulsing) { dot, phase in
                dot.opacity(pulsing && phase ? 0.45 : 1)
            } animation: { _ in .easeInOut(duration: 0.8) }
    }
}

struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
            .background(.surface.opacity(0.6), in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.hairline))
            .environment(\.colorScheme, .dark)
    }
}

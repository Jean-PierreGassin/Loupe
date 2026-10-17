import LoupeCore
import SwiftUI

struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(.tertiaryText)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.hairline).frame(height: 1)
        }
    }
}

struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: String

    init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, format: String) {
        self.title = title
        _value = value
        self.range = range
        self.format = format
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .foregroundStyle(.secondaryText)
                Spacer()
                Text(String(format: format, format.hasSuffix("%%") ? value * 100 : value))
                    .monospacedDigit()
                    .foregroundStyle(.primaryText)
            }
            .font(.label)
            Slider(value: $value, in: range)
        }
    }
}

struct InspectorToggle: View {
    let title: String
    @Binding var isOn: Bool

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.label)
                .foregroundStyle(.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
    }
}

struct BackgroundPicker: View {
    @Binding var selection: BackgroundPreset

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(BackgroundPreset.allCases) { preset in
                Button { selection = preset } label: {
                    swatch(preset)
                        .aspectRatio(1.3, contentMode: .fit)
                        .clipShape(.rect(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.white.opacity(selection == preset ? 0.95 : 0.08), lineWidth: selection == preset ? 2 : 1))
                        .padding(selection == preset ? 0 : 1)
                }
                .buttonStyle(.plain)
                .help(preset.name)
            }
        }
        .animation(.snappy(duration: 0.15), value: selection)
    }

    @ViewBuilder private func swatch(_ preset: BackgroundPreset) -> some View {
        if preset == .none {
            Color.raised.overlay {
                Image(systemName: "nosign")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiaryText)
            }
        } else {
            LinearGradient(colors: [Color(preset.gradient.start), Color(preset.gradient.end)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct CornerPicker: View {
    @Binding var camera: CameraStyle
    let aspect: Double

    var body: some View {
        HStack {
            Text("Position")
                .font(.label)
                .foregroundStyle(.secondaryText)
            Spacer()
            Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    corner(.topLeft)
                    corner(.topRight)
                }
                GridRow {
                    corner(.bottomLeft)
                    corner(.bottomRight)
                }
            }
            .padding(4)
            .background(.white.opacity(0.05), in: .rect(cornerRadius: 8))
        }
    }

    private func corner(_ corner: CameraStyle.Corner) -> some View {
        let target = camera.center(for: corner, aspect: aspect)
        let isSelected = abs(target.x - camera.center.x) < 0.01 && abs(target.y - camera.center.y) < 0.01
        let alignment: Alignment = switch corner {
        case .topLeft: .topLeading
        case .topRight: .topTrailing
        case .bottomLeft: .bottomLeading
        case .bottomRight: .bottomTrailing
        }
        return Button { camera.center = target } label: {
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? .brand.opacity(0.25) : .white.opacity(0.04))
                .frame(width: 34, height: 22)
                .overlay(alignment: alignment) {
                    Circle()
                        .fill(isSelected ? .brand : .secondaryText)
                        .frame(width: 7, height: 7)
                        .padding(4)
                }
        }
        .buttonStyle(.plain)
    }
}

private extension Color {
    init(_ color: RGBA) {
        self.init(.sRGB, red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }
}

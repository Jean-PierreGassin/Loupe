import SwiftUI

struct CountdownView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 18) {
            Text("\(remaining)")
                .font(.system(size: 88, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
                .frame(width: 168, height: 168)
                .background(.ultraThinMaterial, in: .circle)
                .background(.black.opacity(0.3), in: .circle)
                .overlay(Circle().strokeBorder(.white.opacity(0.15)))
            Text("Press ⌥⌘R to cancel")
                .font(.label)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.black.opacity(0.45), in: .capsule)
        }
        .padding(30)
        .animation(.snappy, value: remaining)
    }

    private var remaining: Int {
        if case let .countdown(value) = model.phase { value } else { 0 }
    }
}

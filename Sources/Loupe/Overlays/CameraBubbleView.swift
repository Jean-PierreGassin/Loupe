import AVFoundation
import SwiftUI

struct CameraBubbleView: View {
    static let shadowInset: CGFloat = 28
    static let extent = BubbleSize.allCases.map(\.diameter).max()! + shadowInset * 2

    @Environment(AppModel.self) private var model
    @Environment(PanelHover.self) private var hover

    var body: some View {
        @Bindable var setup = model.setup
        let diameter = setup.bubbleSize.diameter

        CameraPreview(session: model.camera.session)
            .frame(width: diameter, height: diameter)
            .clipShape(.circle)
            .overlay(Circle().strokeBorder(.white.opacity(0.92), lineWidth: 3))
            .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
            .overlay(alignment: .bottom) {
                BubbleSizePicker(selection: $setup.bubbleSize)
                    .padding(.bottom, 12)
                    .opacity(hover.isHovering ? 1 : 0)
                    .offset(y: hover.isHovering ? 0 : 6)
            }
            .contentShape(.circle)
            .gesture(WindowDragGesture())
            .frame(width: Self.extent, height: Self.extent)
            .animation(.snappy(duration: 0.25), value: diameter)
            .animation(.easeOut(duration: 0.18), value: hover.isHovering)
    }
}

private struct BubbleSizePicker: View {
    @Binding var selection: BubbleSize

    var body: some View {
        HStack(spacing: 2) {
            ForEach(BubbleSize.allCases) { size in
                Button { selection = size } label: {
                    Circle()
                        .fill(.white.opacity(selection == size ? 1 : 0.55))
                        .frame(width: size.glyph, height: size.glyph)
                        .frame(width: 24, height: 24)
                        .background(.white.opacity(selection == size ? 0.18 : 0), in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .help("\(size.rawValue.capitalized) bubble")
            }
        }
        .padding(3)
        .background(.black.opacity(0.35), in: .capsule)
        .background(.ultraThinMaterial, in: .capsule)
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
    }
}

private extension BubbleSize {
    var glyph: CGFloat {
        switch self {
        case .small: 6
        case .medium: 9
        case .large: 12
        }
    }
}

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        PreviewView(session: session)
    }

    func updateNSView(_ view: PreviewView, context: Context) {}

    final class PreviewView: NSView {
        private let preview: AVCaptureVideoPreviewLayer

        init(session: AVCaptureSession) {
            preview = AVCaptureVideoPreviewLayer(session: session)
            super.init(frame: .zero)
            layer = CALayer()
            wantsLayer = true
            preview.videoGravity = .resizeAspectFill
            preview.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
            layer?.addSublayer(preview)
            layer?.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func layout() {
            super.layout()
            CATransaction.withoutAnimation { preview.frame = bounds }
        }
    }
}

extension CATransaction {
    static func withoutAnimation(_ body: () -> Void) {
        begin()
        setDisableActions(true)
        body()
        commit()
    }
}

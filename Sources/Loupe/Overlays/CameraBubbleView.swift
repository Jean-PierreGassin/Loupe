import AVFoundation
import SwiftUI

struct CameraBubbleView: View {
    static let shadowInset: CGFloat = 28

    @Environment(AppModel.self) private var model
    @State private var hovering = false

    var body: some View {
        @Bindable var setup = model.setup
        let diameter = setup.bubbleSize.diameter

        CameraPreview(session: model.camera.session)
            .frame(width: diameter, height: diameter)
            .clipShape(.circle)
            .overlay(Circle().strokeBorder(.white.opacity(0.92), lineWidth: 3))
            .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
            .overlay(alignment: .bottom) {
                Picker("Size", selection: $setup.bubbleSize) {
                    ForEach(BubbleSize.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 96)
                .padding(4)
                .background(.ultraThinMaterial, in: .capsule)
                .padding(.bottom, 10)
                .opacity(hovering ? 1 : 0)
            }
            .padding(Self.shadowInset)
            .contentShape(.circle.inset(by: Self.shadowInset))
            .onHover { hovering = $0 }
            .gesture(WindowDragGesture())
            .animation(.snappy(duration: 0.25), value: diameter)
            .animation(.easeOut(duration: 0.15), value: hovering)
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

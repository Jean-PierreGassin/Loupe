import AVFoundation
import LoupeCore
import SwiftUI

struct PreviewStage: View {
    let editor: EditorModel

    var body: some View {
        GeometryReader { proxy in
            let size = fit(aspect: editor.project.aspect, in: proxy.size)
            ZStack {
                PlayerSurface(player: editor.player)
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture(perform: editor.togglePlayback)
                PlayIndicator(isPlaying: editor.isPlaying)
                if editor.project.hasCamera, editor.project.style.camera.visible {
                    CameraHandle(editor: editor, stage: size)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(.rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.hairline))
            .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if let error = editor.loadError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.label)
                        .foregroundStyle(.secondaryText)
                }
            }
        }
    }

    private func fit(aspect: Double, in bounds: CGSize) -> CGSize {
        let width = min(bounds.width, bounds.height * aspect)
        return CGSize(width: width, height: width / aspect)
    }
}

private struct PlayIndicator: View {
    let isPlaying: Bool

    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 60, height: 60)
            .background(.black.opacity(0.35), in: .circle)
            .background(.ultraThinMaterial, in: .circle)
            .opacity(isPlaying ? 0 : 1)
            .scaleEffect(isPlaying ? 1.2 : 1)
            .animation(.snappy(duration: 0.2), value: isPlaying)
            .allowsHitTesting(false)
    }
}

private struct CameraHandle: View {
    let editor: EditorModel
    let stage: CGSize
    @State private var hovering = false
    @State private var dragging = false

    var body: some View {
        let camera = editor.project.style.camera
        let diameter = camera.size * stage.height
        let center = camera.clamped(camera.center, aspect: editor.project.aspect)

        Circle()
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
            .foregroundStyle(.white.opacity(hovering || dragging ? 0.9 : 0))
            .background(Circle().fill(.white.opacity(dragging ? 0.08 : 0.001)))
            .frame(width: diameter + 8, height: diameter + 8)
            .contentShape(.circle)
            .onHover { hovering = $0 }
            .gesture(
                DragGesture(coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        dragging = true
                        let point = NormPoint(value.location.x / stage.width, value.location.y / stage.height)
                        editor.project.style.camera.center = camera.clamped(point, aspect: editor.project.aspect)
                    }
                    .onEnded { _ in dragging = false }
            )
            .help("Drag to move the camera")
            .position(x: center.x * stage.width, y: center.y * stage.height)
            .frame(width: stage.width, height: stage.height)
            .coordinateSpace(.named(Self.space))
            .animation(.easeOut(duration: 0.15), value: hovering)
    }

    private static let space = "stage"
}

struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerLayerView {
        PlayerLayerView(player: player)
    }

    func updateNSView(_ view: PlayerLayerView, context: Context) {}

    final class PlayerLayerView: NSView {
        private let playerLayer: AVPlayerLayer

        init(player: AVPlayer) {
            playerLayer = AVPlayerLayer(player: player)
            super.init(frame: .zero)
            layer = CALayer()
            wantsLayer = true
            layer?.backgroundColor = NSColor.black.cgColor
            playerLayer.videoGravity = .resizeAspect
            layer?.addSublayer(playerLayer)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func layout() {
            super.layout()
            CATransaction.withoutAnimation { playerLayer.frame = bounds }
        }
    }
}

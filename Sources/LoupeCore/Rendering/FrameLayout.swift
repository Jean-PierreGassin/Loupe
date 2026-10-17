import CoreGraphics

struct FrameLayout {
    let canvas: CGRect
    let content: CGRect
    let crop: CGRect
    let cornerRadius: CGFloat
    private let screen: CGSize

    init(screen: CGSize, canvas: CGSize, style: Style, camera: CameraState) {
        self.screen = screen
        self.canvas = CGRect(origin: .zero, size: canvas)

        let padding = style.hasBackground ? style.padding : 0
        content = self.canvas.insetBy(dx: canvas.width * padding, dy: canvas.height * padding).integral
        cornerRadius = style.hasBackground ? style.cornerRadius * canvas.height : 0

        let scale = max(1, camera.scale)
        let size = CGSize(width: screen.width / scale, height: screen.height / scale)
        let centerX = (camera.focus.x * screen.width).clamped(to: size.width / 2...screen.width - size.width / 2)
        let centerY = ((1 - camera.focus.y) * screen.height).clamped(to: size.height / 2...screen.height - size.height / 2)
        crop = CGRect(x: centerX - size.width / 2, y: centerY - size.height / 2, width: size.width, height: size.height)
    }

    var magnification: CGSize {
        CGSize(width: content.width / crop.width, height: content.height / crop.height)
    }

    func project(_ point: NormPoint) -> CGPoint {
        CGPoint(
            x: (point.x * screen.width - crop.minX) * magnification.width + content.minX,
            y: ((1 - point.y) * screen.height - crop.minY) * magnification.height + content.minY
        )
    }
}

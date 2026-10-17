import CoreImage

public enum FrameRenderer {
    static let clickDuration = 0.55
    static let clickColor = (red: 0.55, green: 0.42, blue: 1.0)

    public static func render(screen: CIImage, camera: CIImage?, scene: RenderScene, at compositionTime: Double, canvas: CGSize) -> CIImage {
        let screen = screen.movedToOrigin()
        let time = compositionTime + scene.timeOffset
        let style = scene.style
        let layout = FrameLayout(screen: screen.extent.size, canvas: canvas, style: style, camera: scene.path.state(at: time))

        var frame = backdrop(style, layout: layout)
        frame = screenLayer(screen, layout: layout).composited(over: frame)
        if style.clickHighlights {
            frame = clickLayer(scene.clicks, at: time, layout: layout).composited(over: frame)
        }
        if let camera, style.camera.visible {
            frame = bubble(camera, style: style.camera, canvas: layout.canvas).composited(over: frame)
        }
        return frame.cropped(to: layout.canvas)
    }

    static func backdrop(_ style: Style, layout: FrameLayout) -> CIImage {
        let canvas = layout.canvas
        guard style.hasBackground else { return CIImage(color: .black).cropped(to: canvas) }

        let (start, end) = style.background.gradient
        let gradient = CIImage.linearGradient(
            from: CGPoint(x: 0, y: canvas.height), CIColor(start),
            to: CGPoint(x: canvas.width, y: 0), CIColor(end)
        )
        let glow = CIImage.radialGradient(
            at: CGPoint(x: canvas.width * 0.22, y: canvas.height * 0.92),
            radii: 0...canvas.width * 0.75,
            inner: .white(0.16),
            outer: .white(0)
        )
        var backdrop = glow.composited(over: gradient)
        if style.shadow {
            let shadow = CIImage.roundedRect(layout.content.offsetBy(dx: 0, dy: -canvas.height * 0.012), radius: layout.cornerRadius, color: .black(0.5))
                .applyingGaussianBlur(sigma: canvas.height * 0.022)
            backdrop = shadow.composited(over: backdrop)
        }
        return backdrop.cropped(to: canvas)
    }

    static func screenLayer(_ screen: CIImage, layout: FrameLayout) -> CIImage {
        let view = screen.clampedToExtent()
            .transformed(by: CGAffineTransform(translationX: -layout.crop.minX, y: -layout.crop.minY))
            .cropped(to: CGRect(origin: .zero, size: layout.crop.size))
            .placed(in: layout.content, scale: layout.magnification)
        guard layout.cornerRadius > 0 else { return view }
        return view.masked(by: .roundedRect(layout.content, radius: layout.cornerRadius, color: .white(1)))
    }

    static func clickLayer(_ clicks: [InputEvent], at time: Double, layout: FrameLayout) -> CIImage {
        clicks
            .filter { $0.t <= time && time < $0.t + clickDuration }
            .reduce(CIImage.empty()) { layer, click in
                let point = layout.project(click.position)
                guard layout.content.contains(point) else { return layer }
                let progress = (time - click.t) / clickDuration
                let radius = layout.canvas.height * (0.014 + 0.03 * (1 - pow(1 - progress, 3)))
                let color = { (alpha: Double) in CIColor(red: clickColor.red, green: clickColor.green, blue: clickColor.blue, alpha: alpha) }
                return CIImage.radialGradient(at: point, radii: radius * 0.7...radius, inner: color(0.55 * (1 - progress)), outer: color(0))
                    .cropped(to: layout.content)
                    .composited(over: layer)
            }
    }

    static func bubble(_ camera: CIImage, style: CameraStyle, canvas: CGRect) -> CIImage {
        let extent = camera.extent
        let side = min(extent.width, extent.height)
        guard side > 0 else { return .empty() }

        var face = camera
            .cropped(to: CGRect(x: extent.midX - side / 2, y: extent.midY - side / 2, width: side, height: side))
            .movedToOrigin()
        if style.mirror {
            face = face.transformed(by: CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: side, ty: 0))
        }

        let diameter = (style.size * canvas.height).rounded()
        let center = style.clamped(style.center, aspect: canvas.width / canvas.height)
        let rect = CGRect(
            x: center.x * canvas.width - diameter / 2,
            y: (1 - center.y) * canvas.height - diameter / 2,
            width: diameter,
            height: diameter
        ).integral
        let radius = style.shape == .circle ? rect.width / 2 : rect.width * 0.22
        let border = rect.width * 0.022

        let video = face
            .placed(in: rect, scale: CGSize(width: rect.width / side, height: rect.height / side))
            .masked(by: .roundedRect(rect, radius: radius, color: .white(1)))
        let ring = CIImage.roundedRect(rect.insetBy(dx: -border, dy: -border), radius: radius + border, color: .white(0.92))
        let shadow = CIImage.roundedRect(rect.offsetBy(dx: 0, dy: -rect.width * 0.04), radius: radius, color: .black(0.45))
            .applyingGaussianBlur(sigma: rect.width * 0.06)
        return video.composited(over: ring.composited(over: shadow))
    }
}

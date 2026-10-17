import CoreImage

extension CIImage {
    static func roundedRect(_ rect: CGRect, radius: CGFloat, color: CIColor) -> CIImage {
        CIFilter(name: "CIRoundedRectangleGenerator", parameters: [
            "inputExtent": CIVector(cgRect: rect),
            "inputRadius": radius,
            "inputColor": color,
        ])!.outputImage!
    }

    static func linearGradient(from start: CGPoint, _ startColor: CIColor, to end: CGPoint, _ endColor: CIColor) -> CIImage {
        CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(cgPoint: start),
            "inputPoint1": CIVector(cgPoint: end),
            "inputColor0": startColor,
            "inputColor1": endColor,
        ])!.outputImage!
    }

    static func radialGradient(at center: CGPoint, radii: ClosedRange<CGFloat>, inner: CIColor, outer: CIColor) -> CIImage {
        CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter": CIVector(cgPoint: center),
            "inputRadius0": radii.lowerBound,
            "inputRadius1": radii.upperBound,
            "inputColor0": inner,
            "inputColor1": outer,
        ])!.outputImage!
    }

    func movedToOrigin() -> CIImage {
        transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
    }

    func masked(by mask: CIImage) -> CIImage {
        applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: CIImage.empty(),
            kCIInputMaskImageKey: mask,
        ])
    }

    func resampled(by scale: CGSize) -> CIImage {
        guard scale.width < 0.95 else {
            return samplingLinear().transformed(by: CGAffineTransform(scaleX: scale.width, y: scale.height))
        }
        return applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: scale.height,
            kCIInputAspectRatioKey: scale.width / scale.height,
        ])
    }

    func placed(in rect: CGRect, scale: CGSize) -> CIImage {
        resampled(by: scale)
            .transformed(by: CGAffineTransform(translationX: rect.minX, y: rect.minY))
            .clampedToExtent()
            .cropped(to: rect)
    }
}

extension CIColor {
    convenience init(_ color: RGBA) {
        self.init(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)!
    }

    static func white(_ alpha: CGFloat) -> CIColor { CIColor(red: 1, green: 1, blue: 1, alpha: alpha) }
    static func black(_ alpha: CGFloat) -> CIColor { CIColor(red: 0, green: 0, blue: 0, alpha: alpha) }
}

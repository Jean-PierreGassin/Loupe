import AVFoundation
import CoreImage

final class LoupeInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID = kCMPersistentTrackID_Invalid
    let scene: RenderScene
    let screenTrackID: CMPersistentTrackID
    let cameraTrackID: CMPersistentTrackID?

    init(timeRange: CMTimeRange, scene: RenderScene, screenTrackID: CMPersistentTrackID, cameraTrackID: CMPersistentTrackID?) {
        self.timeRange = timeRange
        self.scene = scene
        self.screenTrackID = screenTrackID
        self.cameraTrackID = cameraTrackID
        requiredSourceTrackIDs = [screenTrackID, cameraTrackID].compactMap { $0.map { NSNumber(value: $0) } }
    }
}

final class LoupeCompositor: NSObject, AVVideoCompositing, Sendable {
    private static let pixelAttributes: [String: any Sendable] = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferMetalCompatibilityKey as String: true,
    ]

    private let context = CIContext(options: [.cacheIntermediates: false, .name: "Loupe"])
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private let queue = DispatchQueue(label: "app.loupe.compositor", qos: .userInitiated)

    var sourcePixelBufferAttributes: [String: any Sendable]? { Self.pixelAttributes }
    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] { Self.pixelAttributes }
    var supportsWideColorSourceFrames: Bool { true }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func cancelAllPendingVideoCompositionRequests() {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        queue.async { [self] in
            guard
                let instruction = request.videoCompositionInstruction as? LoupeInstruction,
                let screen = request.sourceFrame(byTrackID: instruction.screenTrackID),
                let output = request.renderContext.newPixelBuffer()
            else {
                return request.finish(with: LoupeError.missingFrame)
            }
            let camera = instruction.cameraTrackID.flatMap(request.sourceFrame(byTrackID:)).map { CIImage(cvPixelBuffer: $0) }
            let size = request.renderContext.size
            let frame = FrameRenderer.render(
                screen: CIImage(cvPixelBuffer: screen),
                camera: camera,
                scene: instruction.scene,
                at: request.compositionTime.seconds,
                canvas: size
            )
            context.render(frame, to: output, bounds: CGRect(origin: .zero, size: size), colorSpace: colorSpace)
            request.finish(withComposedVideoFrame: output)
        }
    }
}

import AVFoundation
import LoupeCore
import ScreenCaptureKit

@MainActor final class ScreenRecorder {
    struct Configuration {
        var displayID: CGDirectDisplayID
        var camera: CameraFeed?
        var microphoneID: String?
        var systemAudio: Bool
        var destination: URL
    }

    struct Take {
        var duration: Double
        var events: [InputEvent]
        var cursor: [CursorSample]
        var pixelSize: CGSize
        var hasCamera: Bool
    }

    private let configuration: Configuration
    private let stream: SCStream
    private let writer: RecordingWriter
    private let sink: SampleSink
    private let tracker = InputTracker()
    private let displayFrame: CGRect
    private let pixelSize: CGSize

    static func start(_ configuration: Configuration) async throws -> ScreenRecorder {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == configuration.displayID }) else {
            throw RecordingError.displayUnavailable
        }
        let ownApps = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let recorder = try ScreenRecorder(configuration: configuration, display: display, filter: filter)
        try await recorder.begin()
        return recorder
    }

    private init(configuration: Configuration, display: SCDisplay, filter: SCContentFilter) throws {
        let scale = CGFloat(filter.pointPixelScale)
        let pixelSize = CGSize(width: (CGFloat(display.width) * scale / 2).rounded() * 2, height: (CGFloat(display.height) * scale / 2).rounded() * 2)
        let cameraSize = configuration.camera?.dimensions

        writer = try RecordingWriter(url: configuration.destination, configuration: .init(
            screenSize: pixelSize,
            cameraSize: cameraSize,
            systemAudio: configuration.systemAudio,
            microphone: configuration.microphoneID != nil
        ))
        sink = SampleSink(writer: writer, cameraClock: configuration.camera?.session.synchronizationClock)
        stream = SCStream(filter: filter, configuration: Self.streamConfiguration(configuration, pixelSize: pixelSize), delegate: nil)
        self.configuration = configuration
        self.pixelSize = pixelSize
        displayFrame = display.frame
    }

    private func begin() async throws {
        try stream.addStreamOutput(sink, type: .screen, sampleHandlerQueue: writer.queue)
        if configuration.systemAudio {
            try stream.addStreamOutput(sink, type: .audio, sampleHandlerQueue: writer.queue)
        }
        if configuration.microphoneID != nil {
            try stream.addStreamOutput(sink, type: .microphone, sampleHandlerQueue: writer.queue)
        }
        configuration.camera?.deliverFrames(to: sink, on: writer.queue)
        tracker.start()
        try await stream.startCapture()
    }

    func stop() async throws -> Take {
        try? await stream.stopCapture()
        configuration.camera?.deliverFrames(to: nil, on: nil)
        let start = await writer.sessionStart?.seconds ?? HostClock.now.seconds
        let input = tracker.stop(start: start, display: displayFrame)
        let duration = try await writer.finish(at: HostClock.now)
        return Take(
            duration: duration,
            events: input.events.filter { $0.t <= duration },
            cursor: input.cursor,
            pixelSize: pixelSize,
            hasCamera: configuration.camera?.dimensions != nil
        )
    }

    func discard() async {
        try? await stream.stopCapture()
        configuration.camera?.deliverFrames(to: nil, on: nil)
        _ = tracker.stop(start: 0, display: displayFrame)
        await writer.cancel()
    }

    private static func streamConfiguration(_ configuration: Configuration, pixelSize: CGSize) -> SCStreamConfiguration {
        let stream = SCStreamConfiguration()
        stream.width = Int(pixelSize.width)
        stream.height = Int(pixelSize.height)
        stream.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        stream.queueDepth = 6
        stream.showsCursor = true
        stream.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        stream.colorSpaceName = CGColorSpace.sRGB
        stream.capturesAudio = configuration.systemAudio
        stream.excludesCurrentProcessAudio = true
        stream.sampleRate = 48_000
        stream.channelCount = 2
        if let microphoneID = configuration.microphoneID {
            stream.captureMicrophone = true
            stream.microphoneCaptureDeviceID = microphoneID
        }
        return stream
    }
}

private final class SampleSink: NSObject, SCStreamOutput, AVCaptureVideoDataOutputSampleBufferDelegate, Sendable {
    let writer: RecordingWriter
    let cameraClock: CMClock?

    init(writer: RecordingWriter, cameraClock: CMClock?) {
        self.writer = writer
        self.cameraClock = cameraClock
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        let track: RecordingWriter.Track
        switch type {
        case .screen:
            guard buffer.isCompleteScreenFrame else { return }
            track = .screen
        case .audio:
            track = .systemAudio
        case .microphone:
            track = .microphone
        @unknown default:
            return
        }
        writer.receive(buffer, for: track)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput buffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let retimed = cameraClock.map(buffer.retimed(from:)) ?? buffer else { return }
        writer.receive(retimed, for: .camera)
    }
}

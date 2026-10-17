import AVFoundation

actor RecordingWriter {
    enum Track {
        case screen
        case camera
        case systemAudio
        case microphone
    }

    struct Configuration {
        var screenSize: CGSize
        var cameraSize: CMVideoDimensions?
        var systemAudio: Bool
        var microphone: Bool
    }

    nonisolated let queue = DispatchSerialQueue(label: "app.loupe.writer", qos: .userInteractive)
    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    private let writer: AVAssetWriter
    private var inputs: [Track: AVAssetWriterInput] = [:]
    private var startTime: CMTime?
    private var lastScreenFrame: CMSampleBuffer?

    init(url: URL, configuration: Configuration) throws {
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        writer.movieFragmentInterval = CMTime(seconds: 5, preferredTimescale: 600)
        let tracks: [(Track, [String: Any])] = [
            (.screen, Self.screenSettings(configuration.screenSize)),
            configuration.cameraSize.map { (.camera, Self.cameraSettings($0)) },
            configuration.systemAudio ? (.systemAudio, Self.audioSettings(channels: 2)) : nil,
            configuration.microphone ? (.microphone, Self.audioSettings(channels: 1)) : nil,
        ].compactMap { $0 }

        for (track, settings) in tracks {
            let input = AVAssetWriterInput(mediaType: track == .screen || track == .camera ? .video : .audio, outputSettings: settings)
            input.expectsMediaDataInRealTime = true
            guard writer.canAdd(input) else { throw RecordingError.unsupportedFormat }
            writer.add(input)
            inputs[track] = input
        }
        guard writer.startWriting() else { throw writer.error ?? RecordingError.unsupportedFormat }
    }

    nonisolated func receive(_ buffer: CMSampleBuffer, for track: Track) {
        nonisolated(unsafe) let buffer = buffer
        assumeIsolated { $0.append(buffer, to: track) }
    }

    var sessionStart: CMTime? { startTime }

    private func append(_ buffer: CMSampleBuffer, to track: Track) {
        let time = buffer.presentationTimeStamp
        if startTime == nil {
            guard track == .screen else { return }
            writer.startSession(atSourceTime: time)
            startTime = time
        }
        guard let startTime, time >= startTime, let input = inputs[track], input.isReadyForMoreMediaData else { return }
        if input.append(buffer), track == .screen {
            lastScreenFrame = buffer
        }
    }

    func finish(at end: CMTime) async throws -> Double {
        guard let startTime else {
            writer.cancelWriting()
            throw RecordingError.noFrames
        }
        let lastTime = lastScreenFrame?.presentationTimeStamp ?? startTime
        let finalTime = CMTimeMaximum(end, lastTime)
        if let held = lastScreenFrame?.restamped(at: finalTime), finalTime > lastTime, let screen = inputs[.screen], screen.isReadyForMoreMediaData {
            screen.append(held)
        }
        inputs.values.forEach { $0.markAsFinished() }
        writer.endSession(atSourceTime: finalTime)
        await writer.finishWriting()
        if let error = writer.error { throw error }
        return (finalTime - startTime).seconds
    }

    func cancel() {
        writer.cancelWriting()
    }

    private static func screenSettings(_ size: CGSize) -> [String: Any] {
        [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: Int(size.width * size.height * 3.5),
                AVVideoExpectedSourceFrameRateKey: 60,
                AVVideoAllowFrameReorderingKey: false,
            ],
        ]
    }

    private static func cameraSettings(_ size: CMVideoDimensions) -> [String: Any] {
        [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000],
        ]
    }

    private static func audioSettings(channels: Int) -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: channels * 96_000,
        ]
    }
}

enum RecordingError: LocalizedError {
    case displayUnavailable
    case noFrames
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .displayUnavailable: "The selected display is no longer available."
        case .noFrames: "Nothing was captured. Check Screen Recording permission and try again."
        case .unsupportedFormat: "This display or camera format can't be recorded."
        }
    }
}

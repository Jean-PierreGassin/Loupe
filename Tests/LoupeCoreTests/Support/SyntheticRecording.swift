import AVFoundation
import CoreText
import Testing
@testable import LoupeCore

enum SyntheticRecording {
    static let screenSize = CGSize(width: 1440, height: 900)
    static let cameraSize = CGSize(width: 640, height: 480)
    static let fps: Int32 = 30

    static func write(to url: URL, duration: Double, screenDuration: Double? = nil) async throws {
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let screen = input(size: screenSize)
        let camera = input(size: cameraSize)
        let screenAdaptor = adaptor(screen, size: screenSize)
        let cameraAdaptor = adaptor(camera, size: cameraSize)
        writer.add(screen)
        writer.add(camera)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<Int(duration * Double(fps)) {
            let time = CMTime(value: CMTimeValue(frame), timescale: fps)
            let progress = Double(frame) / (duration * Double(fps))
            if time.seconds < screenDuration ?? duration {
                try await append(drawScreen(progress: progress), to: screenAdaptor, at: time)
            } else if screen.isReadyForMoreMediaData {
                screen.markAsFinished()
            }
            try await append(drawCamera(progress: progress), to: cameraAdaptor, at: time)
        }
        if screenDuration == nil {
            screen.markAsFinished()
        }
        camera.markAsFinished()
        await writer.finishWriting()
        if let error = writer.error { throw error }
    }

    static func addingAudioTracks(_ count: Int, to video: URL, output: URL) async throws {
        let source = AVURLAsset(url: video)
        let duration = try await source.load(.duration)
        let composition = AVMutableComposition()
        for track in try await source.loadTracks(withMediaType: .video) {
            let target = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            try target?.insertTimeRange(try await track.load(.timeRange), of: track, at: .zero)
        }
        for index in 0..<count {
            let tone = output.deletingLastPathComponent().appending(path: "tone-\(index).m4a")
            try writeTone(to: tone, frequency: 220 * Double(index + 1), seconds: duration.seconds)
            let toneAsset = AVURLAsset(url: tone)
            let track = try #require(try await toneAsset.loadTracks(withMediaType: .audio).first)
            let target = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try target?.insertTimeRange(try await track.load(.timeRange), of: track, at: .zero)
        }
        try? FileManager.default.removeItem(at: output)
        let session = try #require(AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality))
        try await session.export(to: output, as: .mov)
    }

    private static func writeTone(to url: URL, frequency: Double, seconds: Double) throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let frames = AVAudioFrameCount(seconds * format.sampleRate)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        let samples = try #require(buffer.floatChannelData?[0])
        for frame in 0..<Int(frames) {
            samples[frame] = Float(sin(2 * .pi * frequency * Double(frame) / format.sampleRate) * 0.2)
        }
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: format.sampleRate, AVNumberOfChannelsKey: 1]
        try AVAudioFile(forWriting: url, settings: settings).write(from: buffer)
    }

    private static func input(size: CGSize) -> AVAssetWriterInput {
        AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height,
        ])
    }

    private static func adaptor(_ input: AVAssetWriterInput, size: CGSize) -> AVAssetWriterInputPixelBufferAdaptor {
        AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
        ])
    }

    private static func append(_ buffer: CVPixelBuffer, to adaptor: AVAssetWriterInputPixelBufferAdaptor, at time: CMTime) async throws {
        while !adaptor.assetWriterInput.isReadyForMoreMediaData {
            try await Task.sleep(for: .milliseconds(2))
        }
        adaptor.append(buffer, withPresentationTime: time)
    }

    private static func drawScreen(progress: Double) -> CVPixelBuffer {
        draw(size: screenSize) { context, size in
            context.setFillColor(CGColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1))
            context.fill(CGRect(origin: .zero, size: size))
            context.setFillColor(CGColor(red: 0.16, green: 0.17, blue: 0.22, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 260, height: size.height))
            for row in 0..<14 {
                let y = size.height - 120 - CGFloat(row) * 52
                text("Row \(row + 1)  ·  Quarterly report draft", at: CGPoint(x: 300, y: y), size: 22, in: context)
            }
            context.setFillColor(CGColor(red: 0.42, green: 0.36, blue: 0.95, alpha: 1))
            context.fill(CGRect(x: 1100, y: size.height - 220, width: 220, height: 64))
            text("Publish", at: CGPoint(x: 1160, y: size.height - 200), size: 26, color: .white, in: context)
            context.setFillColor(CGColor(red: 0.9, green: 0.2, blue: 0.3, alpha: 1))
            context.fillEllipse(in: CGRect(x: 300 + progress * 900, y: 60, width: 30, height: 30))
        }
    }

    private static func drawCamera(progress: Double) -> CVPixelBuffer {
        draw(size: cameraSize) { context, size in
            context.setFillColor(CGColor(red: 0.2, green: 0.45, blue: 0.5, alpha: 1))
            context.fill(CGRect(origin: .zero, size: size))
            context.setFillColor(CGColor(red: 0.96, green: 0.8, blue: 0.68, alpha: 1))
            context.fillEllipse(in: CGRect(x: 240 + sin(progress * 12) * 20, y: 140, width: 160, height: 200))
        }
    }

    private static func text(_ string: String, at point: CGPoint, size: CGFloat, color: CGColor = CGColor(gray: 0.15, alpha: 1), in context: CGContext) {
        let attributes = [
            kCTFontAttributeName: CTFontCreateWithName("Helvetica" as CFString, size, nil),
            kCTForegroundColorAttributeName: color,
        ] as CFDictionary
        let line = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, string as CFString, attributes))
        context.textPosition = point
        CTLineDraw(line, context)
    }

    private static func draw(size: CGSize, _ body: (CGContext, CGSize) -> Void) -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, Int(size.width), Int(size.height), kCVPixelFormatType_32BGRA, nil, &buffer)
        let pixels = buffer!
        CVPixelBufferLockBaseAddress(pixels, [])
        defer { CVPixelBufferUnlockBaseAddress(pixels, []) }
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixels),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixels),
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )!
        body(context, size)
        return pixels
    }
}

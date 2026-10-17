import AppKit
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
            let canvas = Canvas(context: context, height: size.height)
            canvas.fill(CGRect(origin: .zero, size: size), 0xF5F6FA)

            canvas.fill(CGRect(x: 0, y: 0, width: 248, height: size.height), 0x12131A)
            canvas.round(CGRect(x: 28, y: 30, width: 34, height: 34), radius: 10, 0x7C5CFA)
            canvas.text("Northwind", at: CGPoint(x: 76, y: 56), size: 21, weight: .bold, color: 0xFFFFFF)
            for (index, item) in ["Overview", "Launches", "Customers", "Analytics", "Reports", "Settings"].enumerated() {
                let y = 118 + Double(index) * 50
                if index == 1 {
                    canvas.round(CGRect(x: 16, y: y - 8, width: 216, height: 42), radius: 10, 0x232533)
                    canvas.round(CGRect(x: 16, y: y - 8, width: 4, height: 42), radius: 2, 0x8B6CFF)
                }
                canvas.round(CGRect(x: 36, y: y + 4, width: 18, height: 18), radius: 5, index == 1 ? 0x8B6CFF : 0x4A4D5E)
                canvas.text(item, at: CGPoint(x: 68, y: y + 20), size: 17, weight: index == 1 ? .semibold : .regular, color: index == 1 ? 0xFFFFFF : 0x9A9DB0)
            }

            canvas.fill(CGRect(x: 248, y: 0, width: size.width - 248, height: 76), 0xFFFFFF)
            canvas.fill(CGRect(x: 248, y: 75, width: size.width - 248, height: 1), 0xE6E8EF)
            canvas.round(CGRect(x: 296, y: 20, width: 420, height: 38), radius: 10, 0xF1F2F6)
            canvas.text("Search launches, people, docs…", at: CGPoint(x: 316, y: 45), size: 15, color: 0x9A9DB0)
            canvas.circle(center: CGPoint(x: 1380, y: 38), radius: 19, 0xF4A261)

            canvas.text("Q3 Product Launch", at: CGPoint(x: 300, y: 178), size: 36, weight: .bold, color: 0x14151C)
            canvas.text("Draft · Last edited 2 minutes ago", at: CGPoint(x: 300, y: 210), size: 16, color: 0x7A7D8F)
            canvas.round(CGRect(x: 1100, y: 156, width: 220, height: 64), radius: 14, 0x7C5CFA)
            canvas.text("Publish", at: CGPoint(x: 1172, y: 196), size: 21, weight: .semibold, color: 0xFFFFFF)

            let headline = "Introducing auto zoom for every click"
            let typed = headline.prefix(Int(((progress - 0.48) / 0.22).clamped(to: 0...1) * Double(headline.count)))
            canvas.text("Headline", at: CGPoint(x: 300, y: 318), size: 15, weight: .semibold, color: 0x4A4D5E)
            canvas.round(CGRect(x: 300, y: 342, width: 1020, height: 64), radius: 12, 0xFFFFFF, stroke: typed.isEmpty ? 0xDADCE5 : 0x8B6CFF)
            let end = canvas.text(String(typed), at: CGPoint(x: 322, y: 384), size: 22, weight: .medium, color: 0x14151C)
            canvas.fill(CGRect(x: end + 2, y: 358, width: 2.5, height: 32), 0x7C5CFA)

            let metrics = [("Signups", "12,480", "+18%"), ("Activation", "64.2%", "+4.1%"), ("Revenue", "$48.9k", "+22%")]
            for (index, metric) in metrics.enumerated() {
                let x = 300 + Double(index) * 348
                canvas.round(CGRect(x: x, y: 438, width: 324, height: 132), radius: 16, 0xFFFFFF, stroke: 0xE6E8EF)
                canvas.text(metric.0, at: CGPoint(x: x + 24, y: 474), size: 15, color: 0x7A7D8F)
                canvas.text(metric.1, at: CGPoint(x: x + 24, y: 526), size: 34, weight: .bold, color: 0x14151C)
                canvas.text(metric.2, at: CGPoint(x: x + 24, y: 554), size: 14, weight: .semibold, color: 0x16A34A)
            }

            canvas.round(CGRect(x: 300, y: 594, width: 1020, height: 270), radius: 16, 0xFFFFFF, stroke: 0xE6E8EF)
            canvas.text("Weekly signups", at: CGPoint(x: 324, y: 632), size: 17, weight: .semibold, color: 0x14151C)
            for bar in 0..<16 {
                let height = 60 + (sin(Double(bar) * 0.7 + progress * 3) * 0.5 + 0.5) * 120 + Double(bar) * 4
                canvas.round(CGRect(x: 330 + Double(bar) * 61, y: 844 - height, width: 38, height: height), radius: 8, bar == 15 ? 0x7C5CFA : 0xD9D0FF)
            }
        }
    }

    private static func drawCamera(progress: Double) -> CVPixelBuffer {
        draw(size: cameraSize) { context, size in
            let colors = [CGColor(red: 0.98, green: 0.82, blue: 0.66, alpha: 1), CGColor(red: 0.86, green: 0.42, blue: 0.52, alpha: 1)] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1])!
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: 0), options: [])
            let sway = sin(progress * 12) * 8
            context.setFillColor(CGColor(red: 0.2, green: 0.17, blue: 0.3, alpha: 1))
            context.fillEllipse(in: CGRect(x: 150 + sway, y: -170, width: 340, height: 330))
            context.setFillColor(CGColor(red: 0.25, green: 0.18, blue: 0.16, alpha: 1))
            context.fillEllipse(in: CGRect(x: 232 + sway, y: 200, width: 176, height: 180))
            context.setFillColor(CGColor(red: 0.95, green: 0.76, blue: 0.64, alpha: 1))
            context.fillEllipse(in: CGRect(x: 248 + sway, y: 160, width: 144, height: 176))
        }
    }

    private struct Canvas {
        let context: CGContext
        let height: Double

        func fill(_ rect: CGRect, _ hex: UInt32) {
            context.setFillColor(color(hex))
            context.fill(flip(rect))
        }

        func round(_ rect: CGRect, radius: Double, _ hex: UInt32, stroke: UInt32? = nil) {
            let path = CGPath(roundedRect: flip(rect), cornerWidth: radius, cornerHeight: radius, transform: nil)
            context.addPath(path)
            context.setFillColor(color(hex))
            context.fillPath()
            if let stroke {
                context.addPath(path)
                context.setStrokeColor(color(stroke))
                context.setLineWidth(1.5)
                context.strokePath()
            }
        }

        func circle(center: CGPoint, radius: Double, _ hex: UInt32) {
            context.setFillColor(color(hex))
            context.fillEllipse(in: flip(CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)))
        }

        @discardableResult
        func text(_ string: String, at point: CGPoint, size: Double, weight: NSFont.Weight = .regular, color hex: UInt32) -> Double {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: NSColor(cgColor: color(hex))!,
            ]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
            context.textPosition = CGPoint(x: point.x, y: height - point.y)
            CTLineDraw(line, context)
            return point.x + CTLineGetTypographicBounds(line, nil, nil, nil)
        }

        private func flip(_ rect: CGRect) -> CGRect {
            CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
        }

        private func color(_ hex: UInt32) -> CGColor {
            CGColor(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, alpha: 1)
        }
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

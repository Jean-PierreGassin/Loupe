import AVFoundation

enum AudioMixdown {
    static func render(_ tracks: [AVAssetTrack], of asset: AVAsset, range: CMTimeRange, to url: URL) async throws -> Bool {
        try? FileManager.default.removeItem(at: url)
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = range
        let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
        ])
        guard reader.canAdd(output) else { throw LoupeError.compositionFailed }
        reader.add(output)

        let writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 192_000,
        ])
        guard writer.canAdd(input) else { throw LoupeError.compositionFailed }
        writer.add(input)
        guard reader.startReading(), writer.startWriting() else {
            throw reader.error ?? writer.error ?? LoupeError.compositionFailed
        }
        writer.startSession(atSourceTime: range.start)

        var wroteSamples = false
        do {
            while let buffer = output.copyNextSampleBuffer() {
                while !input.isReadyForMoreMediaData {
                    guard writer.status == .writing else { throw writer.error ?? LoupeError.compositionFailed }
                    try await Task.sleep(for: .milliseconds(5))
                }
                try Task.checkCancellation()
                guard input.append(buffer) else { throw writer.error ?? LoupeError.compositionFailed }
                wroteSamples = true
            }
            if reader.status == .failed { throw reader.error ?? LoupeError.compositionFailed }
        } catch {
            reader.cancelReading()
            writer.cancelWriting()
            throw error
        }
        guard wroteSamples else {
            writer.cancelWriting()
            return false
        }
        input.markAsFinished()
        await writer.finishWriting()
        if let error = writer.error { throw error }
        return true
    }
}

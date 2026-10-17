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
        while let buffer = output.copyNextSampleBuffer() {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(for: .milliseconds(5))
            }
            guard input.append(buffer) else { break }
            wroteSamples = true
        }
        guard reader.status != .failed, wroteSamples else {
            writer.cancelWriting()
            if let error = reader.error { throw error }
            return false
        }
        input.markAsFinished()
        await writer.finishWriting()
        if let error = writer.error { throw error }
        return true
    }
}

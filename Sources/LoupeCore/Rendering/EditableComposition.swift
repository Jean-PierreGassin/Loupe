import AVFoundation

public struct EditableComposition: @unchecked Sendable {
    public let asset: AVComposition
    public let screenSize: CGSize
    let screenTrackID: CMPersistentTrackID
    let cameraTrackID: CMPersistentTrackID?

    public init(recording url: URL, project: Project, mixingAudioTo mixdown: URL? = nil) async throws {
        let source = AVURLAsset(url: url)
        let videoTracks = try await source.loadTracks(withMediaType: .video).sorted { $0.trackID < $1.trackID }
        let audioTracks = try await source.loadTracks(withMediaType: .audio)
        guard let screenTrack = videoTracks.first else { throw LoupeError.missingScreenTrack }

        let duration = try await source.load(.duration)
        let start = CMTime(seconds: project.trimStart, preferredTimescale: 600)
        let end = CMTimeMinimum(CMTime(seconds: project.trimEnd, preferredTimescale: 600), duration)
        let range = CMTimeRange(start: start, end: CMTimeMaximum(end, start + CMTime(value: 1, timescale: 30)))

        let composition = AVMutableComposition()
        func insert(_ track: AVAssetTrack) async throws -> CMPersistentTrackID {
            guard let target = composition.addMutableTrack(withMediaType: track.mediaType, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw LoupeError.compositionFailed
            }
            let available = range.intersection(try await track.load(.timeRange))
            guard !available.isEmpty else { return target.trackID }
            try target.insertTimeRange(available, of: track, at: available.start - range.start)
            return target.trackID
        }

        screenTrackID = try await insert(screenTrack)
        cameraTrackID = videoTracks.count > 1 ? try await insert(videoTracks[1]) : nil
        if let mixdown, audioTracks.count > 1 {
            let mixedAsset = AVURLAsset(url: mixdown)
            if try await AudioMixdown.render(audioTracks, of: source, range: range, to: mixdown),
               let mixed = try await mixedAsset.loadTracks(withMediaType: .audio).first,
               let target = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                let mixedRange = try await mixed.load(.timeRange)
                try target.insertTimeRange(mixedRange, of: mixed, at: mixedRange.start)
            }
        } else {
            for track in audioTracks {
                _ = try await insert(track)
            }
        }
        screenSize = try await screenTrack.load(.naturalSize)
        asset = composition
    }

    public func renderSize(width: Int) -> CGSize {
        let evenWidth = width / 2 * 2
        let height = Double(evenWidth) * screenSize.height / max(1, screenSize.width)
        return CGSize(width: evenWidth, height: Int((height / 2).rounded()) * 2)
    }

    public func videoComposition(for project: Project, width: Int) -> AVVideoComposition {
        let composition = AVMutableVideoComposition()
        composition.customVideoCompositorClass = LoupeCompositor.self
        composition.renderSize = renderSize(width: width)
        composition.frameDuration = CMTime(value: 1, timescale: 60)
        composition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
        composition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
        composition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
        composition.instructions = [
            LoupeInstruction(
                timeRange: CMTimeRange(start: .zero, duration: asset.duration),
                scene: RenderScene(project: project),
                screenTrackID: screenTrackID,
                cameraTrackID: project.hasCamera ? cameraTrackID : nil
            ),
        ]
        return composition
    }
}

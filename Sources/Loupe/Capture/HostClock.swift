import CoreMedia
import ScreenCaptureKit

enum HostClock {
    static var now: CMTime { CMClockGetTime(CMClockGetHostTimeClock()) }
}

extension CMSampleBuffer {
    var isCompleteScreenFrame: Bool {
        guard
            let attachments = CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
            let rawStatus = attachments.first?[.status] as? Int
        else { return false }
        return SCFrameStatus(rawValue: rawStatus) == .complete
    }

    func retimed(from clock: CMClock) -> CMSampleBuffer? {
        let host = CMClockGetHostTimeClock()
        guard !CFEqual(clock, host) else { return self }
        var timing = CMSampleTimingInfo()
        CMSampleBufferGetSampleTimingInfo(self, at: 0, timingInfoOut: &timing)
        timing.presentationTimeStamp = CMSyncConvertTime(timing.presentationTimeStamp, from: clock, to: host)
        timing.decodeTimeStamp = .invalid
        var copy: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: self, sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleBufferOut: &copy)
        return copy
    }
}

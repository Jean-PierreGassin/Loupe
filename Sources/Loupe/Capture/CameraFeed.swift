import AVFoundation
import Synchronization

final class CameraFeed: @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "io.github.jean-pierregassin.Loupe.camera")
    private var device: AVCaptureDevice?
    private let activeDimensions = Mutex<CMVideoDimensions?>(nil)

    init() {
        output.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
    }

    var dimensions: CMVideoDimensions? {
        activeDimensions.withLock { $0 }
    }

    func use(deviceID: String?) {
        queue.async { [self] in
            guard device?.uniqueID != deviceID || !session.isRunning else { return }
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            device = nil
            if let candidate = deviceID.flatMap(AVCaptureDevice.init(uniqueID:)),
               let input = try? AVCaptureDeviceInput(device: candidate),
               session.canAddInput(input) {
                session.addInput(input)
                session.sessionPreset = session.canSetSessionPreset(.hd1280x720) ? .hd1280x720 : .high
                device = candidate
            }
            session.commitConfiguration()
            let dimensions = device.map { CMVideoFormatDescriptionGetDimensions($0.activeFormat.formatDescription) }
            activeDimensions.withLock { $0 = dimensions }
            if device == nil {
                session.stopRunning()
            } else if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stop() {
        queue.async { [self] in
            session.stopRunning()
            device = nil
            activeDimensions.withLock { $0 = nil }
        }
    }

    func deliverFrames(to delegate: (any AVCaptureVideoDataOutputSampleBufferDelegate)?, on delegateQueue: DispatchQueue?) {
        output.setSampleBufferDelegate(delegate, queue: delegateQueue)
    }
}

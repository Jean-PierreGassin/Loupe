import AVFoundation

final class CameraFeed: @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "app.loupe.camera")
    private var device: AVCaptureDevice?

    init() {
        output.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
    }

    var dimensions: CMVideoDimensions? {
        queue.sync { device.map { CMVideoFormatDescriptionGetDimensions($0.activeFormat.formatDescription) } }
    }

    func use(deviceID: String?) {
        queue.async { [self] in
            guard device?.uniqueID != deviceID || !session.isRunning else { return }
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            device = deviceID.flatMap(AVCaptureDevice.init(uniqueID:))
            if let device, let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
                session.addInput(input)
                session.sessionPreset = session.canSetSessionPreset(.hd1280x720) ? .hd1280x720 : .high
            }
            session.commitConfiguration()
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
        }
    }

    func deliverFrames(to delegate: (any AVCaptureVideoDataOutputSampleBufferDelegate)?, on delegateQueue: DispatchQueue?) {
        output.setSampleBufferDelegate(delegate, queue: delegateQueue)
    }
}

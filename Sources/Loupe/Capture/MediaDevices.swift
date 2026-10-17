import AppKit
import AVFoundation

struct MediaDevice: Identifiable, Hashable {
    let id: String
    let name: String
}

struct DisplayOption: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    let frame: NSRect
}

enum MediaDevices {
    static var cameras: [MediaDevice] {
        devices(of: [.builtInWideAngleCamera, .external, .continuityCamera], mediaType: .video)
    }

    static var microphones: [MediaDevice] {
        devices(of: [.microphone, .external], mediaType: .audio)
    }

    static var systemCamera: String? {
        AVCaptureDevice.default(for: .video)?.uniqueID
    }

    static var systemMicrophone: String? {
        AVCaptureDevice.default(for: .audio)?.uniqueID
    }

    @MainActor static var displays: [DisplayOption] {
        NSScreen.screens.compactMap { screen in
            screen.displayID.map { DisplayOption(id: $0, name: screen.localizedName, frame: screen.frame) }
        }
    }

    private static func devices(of types: [AVCaptureDevice.DeviceType], mediaType: AVMediaType) -> [MediaDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: mediaType, position: .unspecified)
            .devices
            .map { MediaDevice(id: $0.uniqueID, name: $0.localizedName) }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    static func matching(_ displayID: CGDirectDisplayID) -> NSScreen? {
        screens.first { $0.displayID == displayID }
    }
}

import AppKit
import Foundation

enum BubbleSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: Self { self }

    var diameter: CGFloat {
        switch self {
        case .small: 150
        case .medium: 210
        case .large: 290
        }
    }

}

@MainActor @Observable final class CaptureSetup {
    private(set) var displays: [DisplayOption] = []
    private(set) var cameras: [MediaDevice] = []
    private(set) var microphones: [MediaDevice] = []
    private(set) var missingPermissions: [Permission] = []
    private(set) var cameraID: String?
    private(set) var microphoneID: String?

    var displayID: CGDirectDisplayID?
    var systemAudio: Bool { didSet { defaults.set(systemAudio, forKey: Key.systemAudio) } }
    var bubbleSize: BubbleSize { didSet { defaults.set(bubbleSize.rawValue, forKey: Key.bubbleSize) } }

    private let defaults = UserDefaults.standard

    private enum Key {
        static let camera = "preferredCamera"
        static let microphone = "preferredMicrophone"
        static let systemAudio = "systemAudio"
        static let bubbleSize = "bubbleSize"
    }

    init() {
        systemAudio = defaults.object(forKey: Key.systemAudio) as? Bool ?? true
        bubbleSize = defaults.string(forKey: Key.bubbleSize).flatMap(BubbleSize.init) ?? .medium
    }

    var display: DisplayOption? {
        displays.first { $0.id == displayID } ?? displays.first
    }

    var canRecord: Bool {
        !missingPermissions.contains(.screen)
    }

    func chooseCamera(_ id: String?) {
        defaults.set(id ?? "", forKey: Key.camera)
        cameraID = id
    }

    func chooseMicrophone(_ id: String?) {
        defaults.set(id ?? "", forKey: Key.microphone)
        microphoneID = id
    }

    func refresh() {
        update(\.displays, to: MediaDevices.displays)
        update(\.cameras, to: Permission.camera.isGranted ? MediaDevices.cameras : [])
        update(\.microphones, to: Permission.microphone.isGranted ? MediaDevices.microphones : [])
        update(\.missingPermissions, to: Permission.allCases.filter { !$0.isGranted })
        update(\.cameraID, to: resolve(defaults.string(forKey: Key.camera), in: cameras, system: MediaDevices.systemCamera))
        update(\.microphoneID, to: resolve(defaults.string(forKey: Key.microphone), in: microphones, system: MediaDevices.systemMicrophone))

        if displayID == nil || !displays.contains(where: { $0.id == displayID }) {
            displayID = NSScreen.main?.displayID ?? displays.first?.id
        }
    }

    private func resolve(_ preference: String?, in devices: [MediaDevice], system: String?) -> String? {
        if preference == "" { return nil }
        let available = Set(devices.map(\.id))
        return [preference, system, devices.first?.id].compactMap { $0 }.first(where: available.contains)
    }

    private func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<CaptureSetup, Value>, to value: Value) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }
}

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

    var label: String { String(rawValue.prefix(1)).uppercased() }
}

@MainActor @Observable final class CaptureSetup {
    private(set) var displays: [DisplayOption] = []
    private(set) var cameras: [MediaDevice] = []
    private(set) var microphones: [MediaDevice] = []
    private(set) var missingPermissions: [Permission] = []

    var displayID: CGDirectDisplayID?
    var cameraID: String? { didSet { defaults.set(cameraID ?? "", forKey: "cameraID") } }
    var microphoneID: String? { didSet { defaults.set(microphoneID ?? "", forKey: "microphoneID") } }
    var systemAudio: Bool { didSet { defaults.set(systemAudio, forKey: "systemAudio") } }
    var bubbleSize: BubbleSize { didSet { defaults.set(bubbleSize.rawValue, forKey: "bubbleSize") } }

    private let defaults = UserDefaults.standard

    init() {
        cameraID = defaults.string(forKey: "cameraID").flatMap { $0.isEmpty ? nil : $0 }
        microphoneID = defaults.string(forKey: "microphoneID").flatMap { $0.isEmpty ? nil : $0 }
        systemAudio = defaults.object(forKey: "systemAudio") as? Bool ?? true
        bubbleSize = defaults.string(forKey: "bubbleSize").flatMap(BubbleSize.init) ?? .medium
    }

    var display: DisplayOption? {
        displays.first { $0.id == displayID } ?? displays.first
    }

    var canRecord: Bool {
        !missingPermissions.contains(.screen)
    }

    func refresh() {
        update(\.displays, to: MediaDevices.displays)
        update(\.cameras, to: Permission.camera.isGranted ? MediaDevices.cameras : [])
        update(\.microphones, to: Permission.microphone.isGranted ? MediaDevices.microphones : [])
        update(\.missingPermissions, to: Permission.allCases.filter { !$0.isGranted })

        if displayID == nil || !displays.contains(where: { $0.id == displayID }) {
            displayID = NSScreen.main?.displayID ?? displays.first?.id
        }
        if let cameraID, !cameras.contains(where: { $0.id == cameraID }) {
            self.cameraID = cameras.first?.id
        }
        if let microphoneID, !microphones.contains(where: { $0.id == microphoneID }) {
            self.microphoneID = microphones.first?.id
        }
        if defaults.string(forKey: "cameraID") == nil, let first = cameras.first {
            cameraID = first.id
        }
        if defaults.string(forKey: "microphoneID") == nil, let first = microphones.first {
            microphoneID = first.id
        }
    }

    private func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<CaptureSetup, Value>, to value: Value) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }
}

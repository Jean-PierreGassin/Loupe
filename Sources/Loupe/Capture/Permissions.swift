import AppKit
import AVFoundation
import CoreGraphics

enum Permission: CaseIterable, Identifiable {
    case screen
    case camera
    case microphone
    case accessibility

    var id: Self { self }

    var title: String {
        switch self {
        case .screen: "Screen Recording"
        case .camera: "Camera"
        case .microphone: "Microphone"
        case .accessibility: "Accessibility"
        }
    }

    var reason: String {
        switch self {
        case .screen: "Required to record your screen."
        case .camera: "Needed for the webcam bubble."
        case .microphone: "Needed to record your voice."
        case .accessibility: "Lets Loupe zoom in while you type."
        }
    }

    var isGranted: Bool {
        switch self {
        case .screen: CGPreflightScreenCaptureAccess()
        case .camera: AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        case .microphone: AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        case .accessibility: AXIsProcessTrusted()
        }
    }

    @MainActor func request() async {
        switch self {
        case .screen:
            if !CGRequestScreenCaptureAccess() {
                openSettings("Privacy_ScreenCapture")
            }
        case .camera:
            await requestMedia(.video, pane: "Privacy_Camera")
        case .microphone:
            await requestMedia(.audio, pane: "Privacy_Microphone")
        case .accessibility:
            let prompt = "AXTrustedCheckOptionPrompt" as CFString
            if !AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary) {
                openSettings("Privacy_Accessibility")
            }
        }
    }

    @MainActor private func requestMedia(_ type: AVMediaType, pane: String) async {
        if AVCaptureDevice.authorizationStatus(for: type) == .notDetermined {
            await AVCaptureDevice.requestAccess(for: type)
        } else {
            openSettings(pane)
        }
    }

    @MainActor private func openSettings(_ pane: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
    }
}

import Foundation

public enum LoupeError: LocalizedError {
    case missingFrame
    case missingScreenTrack
    case compositionFailed
    case exportUnavailable

    public var errorDescription: String? {
        switch self {
        case .missingFrame: "A source frame was missing while rendering."
        case .missingScreenTrack: "This recording has no screen video."
        case .compositionFailed: "The recording could not be prepared for editing."
        case .exportUnavailable: "Exporting is unavailable on this Mac."
        }
    }
}

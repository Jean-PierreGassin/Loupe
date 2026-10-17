public struct InputEvent: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case click
        case key
    }

    public var t: Double
    public var kind: Kind
    public var position: NormPoint

    public init(t: Double, kind: Kind, position: NormPoint) {
        self.t = t
        self.kind = kind
        self.position = position
    }
}

public struct CursorSample: Codable, Hashable, Sendable {
    public var t: Double
    public var position: NormPoint

    public init(t: Double, position: NormPoint) {
        self.t = t
        self.position = position
    }
}

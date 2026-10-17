public struct CameraState: Hashable, Sendable {
    public var scale: Double
    public var focus: NormPoint

    public static let identity = CameraState(scale: 1, focus: .center)

    public init(scale: Double, focus: NormPoint) {
        self.scale = scale
        self.focus = focus
    }
}

public struct CameraPath: Sendable {
    public let fps: Double
    public let states: [CameraState]

    public init(fps: Double, states: [CameraState]) {
        self.fps = fps
        self.states = states
    }

    public func state(at t: Double) -> CameraState {
        guard let last = states.last else { return .identity }
        let frame = max(0, t * fps)
        let index = Int(frame)
        guard index < states.count - 1 else { return last }
        let a = states[index]
        let b = states[index + 1]
        let u = frame - Double(index)
        return CameraState(
            scale: a.scale.mix(b.scale, u),
            focus: NormPoint(a.focus.x.mix(b.focus.x, u), a.focus.y.mix(b.focus.y, u))
        )
    }
}

struct Spring {
    var value: Double
    var velocity = 0.0
    let omega: Double

    mutating func step(toward target: Double, dt: Double) {
        velocity += (omega * omega * (target - value) - 2 * omega * velocity) * dt
        value += velocity * dt
    }

    mutating func snap(to target: Double) {
        value = target
        velocity = 0
    }
}

struct CursorTrack {
    let samples: [CursorSample]

    func position(at t: Double) -> NormPoint? {
        guard let first = samples.first, let last = samples.last else { return nil }
        guard t > first.t else { return first.position }
        guard t < last.t else { return last.position }
        var low = 0
        var high = samples.count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if samples[mid].t <= t { low = mid } else { high = mid }
        }
        let a = samples[low]
        let b = samples[high]
        let u = b.t > a.t ? (t - a.t) / (b.t - a.t) : 0
        return NormPoint(a.position.x.mix(b.position.x, u), a.position.y.mix(b.position.y, u))
    }
}

extension Double {
    func mix(_ other: Double, _ amount: Double) -> Double {
        self + (other - self) * amount
    }
}

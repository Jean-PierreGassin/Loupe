public struct RenderScene: Sendable {
    public var style: Style
    public var path: CameraPath
    public var clicks: [InputEvent]
    public var timeOffset: Double

    public init(style: Style, path: CameraPath, clicks: [InputEvent], timeOffset: Double = 0) {
        self.style = style
        self.path = path
        self.clicks = clicks
        self.timeOffset = timeOffset
    }

    public init(project: Project) {
        self.init(
            style: project.style,
            path: ZoomPlanner.cameraPath(for: project),
            clicks: project.events.filter { $0.kind == .click },
            timeOffset: project.trimStart
        )
    }
}

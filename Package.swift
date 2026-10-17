// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Loupe",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "LoupeCore", path: "Sources/LoupeCore"),
        .executableTarget(name: "Loupe", dependencies: ["LoupeCore"], path: "Sources/Loupe"),
        .testTarget(name: "LoupeCoreTests", dependencies: ["LoupeCore"], path: "Tests/LoupeCoreTests"),
        .testTarget(name: "LoupeTests", dependencies: ["Loupe"], path: "Tests/LoupeTests"),
    ]
)

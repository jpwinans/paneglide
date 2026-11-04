// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PaneGlide",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PaneGlide", targets: ["PaneGlideApp"]), .executable(name: "UpdateAcceptance", targets: ["UpdateAcceptance"])],
    targets: [
        .target(name: "PaneGlideCore"),
        .target(name: "PaneGlidePlatform", dependencies: ["PaneGlideCore"]),
        .executableTarget(name: "PaneGlideApp", dependencies: ["PaneGlideCore", "PaneGlidePlatform"]),
        .executableTarget(name: "UpdateAcceptance", dependencies: ["PaneGlideCore", "PaneGlidePlatform"], path: "Tools/UpdateAcceptance"),
        .testTarget(name: "PaneGlideCoreTests", dependencies: ["PaneGlideCore"])
    ]
)

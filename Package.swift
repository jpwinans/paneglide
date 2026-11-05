// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PaneGlide",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PaneGlide", targets: ["PaneGlideApp"])],
    targets: [
        .target(name: "PaneGlideCore"),
        .executableTarget(name: "PaneGlideApp", dependencies: ["PaneGlideCore"]),
        .testTarget(name: "PaneGlideCoreTests", dependencies: ["PaneGlideCore"])
    ]
)

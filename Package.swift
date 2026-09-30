// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BeeHanBrightness",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "BeeHanBrightness"),
        .testTarget(name: "BeeHanBrightnessTests", dependencies: ["BeeHanBrightness"]),
    ],
    swiftLanguageModes: [.v5]
)

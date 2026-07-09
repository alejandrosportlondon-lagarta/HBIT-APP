// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AlarmEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "AlarmEngine", targets: ["AlarmEngine"])
    ],
    targets: [
        .target(name: "AlarmEngine"),
        .testTarget(name: "AlarmEngineTests", dependencies: ["AlarmEngine"])
    ]
)

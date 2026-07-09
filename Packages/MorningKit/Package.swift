// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MorningKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MorningKit", targets: ["MorningKit"])
    ],
    targets: [
        .target(name: "MorningKit"),
        .testTarget(name: "MorningKitTests", dependencies: ["MorningKit"])
    ]
)

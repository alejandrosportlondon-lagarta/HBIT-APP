// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PaywallKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PaywallKit", targets: ["PaywallKit"])
    ],
    targets: [
        .target(name: "PaywallKit"),
        .testTarget(name: "PaywallKitTests", dependencies: ["PaywallKit"])
    ]
)

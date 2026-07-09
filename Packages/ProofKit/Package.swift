// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProofKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ProofKit", targets: ["ProofKit"])
    ],
    targets: [
        .target(name: "ProofKit"),
        .testTarget(name: "ProofKitTests", dependencies: ["ProofKit"])
    ]
)

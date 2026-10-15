// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuantumToy",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [.library(name: "QuantumCore", targets: ["QuantumCore"])],
    targets: [
        .target(name: "QuantumCore"),
        .testTarget(name: "QuantumCoreTests", dependencies: ["QuantumCore"])
    ]
)

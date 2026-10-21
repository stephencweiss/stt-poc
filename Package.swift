// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "STTPOC",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "STTCore", targets: ["STTCore"]),
        .library(name: "STTAdapters", targets: ["STTAdapters"]),
        .executable(name: "STTPractice", targets: ["STTPractice"]),
        .executable(name: "STTBenchmark", targets: ["STTBenchmark"]),
    ],
    targets: [
        .target(name: "STTCore"),
        .target(name: "STTAdapters", dependencies: ["STTCore"]),
        .executableTarget(name: "STTPractice", dependencies: ["STTCore", "STTAdapters"]),
        .executableTarget(name: "STTBenchmark", dependencies: ["STTCore", "STTAdapters"]),
        .testTarget(
            name: "STTBenchmarkTests", dependencies: ["STTBenchmark", "STTCore", "STTAdapters"]),
        .testTarget(name: "STTCoreTests", dependencies: ["STTCore"]),
        .testTarget(name: "STTAdaptersTests", dependencies: ["STTAdapters", "STTCore"]),
    ],
    swiftLanguageModes: [.v6]
)

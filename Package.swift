// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AnsiCore",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "AnsiCore",
            targets: ["AnsiCore"]
        )
    ],
    targets: [
        .target(
            name: "AnsiCore",
            path: "Sources/AnsiCore"
        ),
        .testTarget(
            name: "AnsiCoreTests",
            dependencies: ["AnsiCore"],
            path: "Tests/AnsiCoreTests"
        )
    ]
)

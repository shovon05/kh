// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "kh",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "kh",
            path: "Sources/kh",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Foundation")
            ]
        )
    ]
)

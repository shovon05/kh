// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "cmk",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "cmk",
            path: "Sources/cmk",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Foundation")
            ]
        )
    ]
)

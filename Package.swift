// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "kh",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "kh", targets: ["kh"]),
        .library(name: "KeyboardHibernateCore", targets: ["KeyboardHibernateCore"])
    ],
    targets: [
        .target(
            name: "KeyboardHibernateCore",
            path: "Sources/KeyboardHibernateCore"
        ),
        .executableTarget(
            name: "kh",
            dependencies: ["KeyboardHibernateCore"],
            path: "Sources/kh"
        ),
        .testTarget(
            name: "KeyboardHibernateCoreTests",
            dependencies: ["KeyboardHibernateCore"],
            path: "Tests/KeyboardHibernateCoreTests"
        )
    ]
)

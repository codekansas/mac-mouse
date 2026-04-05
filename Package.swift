// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacMouse",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "MacMouse", targets: ["MacMouse"]),
    ],
    targets: [
        .target(name: "MacMouseCore"),
        .executableTarget(
            name: "MacMouse",
            dependencies: ["MacMouseCore"]
        ),
        .testTarget(
            name: "MacMouseCoreTests",
            dependencies: ["MacMouseCore"]
        ),
    ]
)

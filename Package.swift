// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Shouping",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Shouping", targets: ["Shouping"]),
        .executable(name: "ShoupingAgent", targets: ["ShoupingAgent"]),
        .executable(name: "ShoupingChecks", targets: ["ShoupingChecks"]),
        .library(name: "ShoupingCore", targets: ["ShoupingCore"]),
    ],
    targets: [
        .target(
            name: "ShoupingCore",
            path: "Sources/ShoupingCore"
        ),
        .executableTarget(
            name: "Shouping",
            dependencies: ["ShoupingCore"],
            path: "Sources/Shouping"
        ),
        .executableTarget(
            name: "ShoupingAgent",
            dependencies: ["ShoupingCore"],
            path: "Sources/ShoupingAgent"
        ),
        .executableTarget(
            name: "ShoupingChecks",
            dependencies: ["ShoupingCore"],
            path: "Sources/ShoupingChecks"
        ),
    ]
)

// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MySocket",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "MySocket",
            targets: ["MySocket"]),
        .executable(name: "MyServer", targets: ["MyServer"])
    ],
    targets: [
        .target(
            name: "MySocket"),
        .executableTarget(
            name: "MyServer",
            dependencies: [
                "MySocket"
            ],
            resources: [
                .copy("Resources/")
            ]
        ),
    ]
)

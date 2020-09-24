// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "SwissTable",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "SwissTable",
            targets: ["SwissTable"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "SwissTable",
            dependencies: [],
            swiftSettings: [
                .unsafeFlags(["-Xcc", "-mavx2"]),
            ]
        ),
        .testTarget(
            name: "SwissTableTests",
            dependencies: ["SwissTable"]),
    ]
)

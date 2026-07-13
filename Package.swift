// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "TabTap",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "TabTapCore", targets: ["TabTapCore"]),
        .executable(name: "TabTap", targets: ["TabTap"]),
    ],
    targets: [
        .target(name: "TabTapCore"),
        .executableTarget(
            name: "TabTap",
            dependencies: ["TabTapCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "TabTapCoreTests",
            dependencies: ["TabTapCore"]
        ),
    ]
)

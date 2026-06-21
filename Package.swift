// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HaloCallPop",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "HaloCallPop", targets: ["HaloCallPop"]),
        .executable(name: "HaloCallPopSelfTest", targets: ["HaloCallPopSelfTest"])
    ],
    targets: [
        .target(
            name: "HaloCallPop",
            path: "HaloCallPop",
            exclude: [
                "Info.plist",
                "HaloCallPop.entitlements",
                "Assets.xcassets",
                "HaloCallPopApp.swift"
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .executableTarget(
            name: "HaloCallPopSelfTest",
            dependencies: ["HaloCallPop"],
            path: "Sources/HaloCallPopSelfTest"
        ),
        .testTarget(
            name: "HaloCallPopTests",
            dependencies: ["HaloCallPop"],
            path: "HaloCallPopTests"
        )
    ]
)

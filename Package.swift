// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "localshot",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "LocalShotLib",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreImage"),
                .linkedFramework("QuartzCore")
            ]
        ),
        .executableTarget(
            name: "localshot",
            dependencies: ["LocalShotLib"]
        )
    ]
)

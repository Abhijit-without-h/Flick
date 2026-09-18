// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Flick",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Flick", targets: ["Flick"]),
        .library(name: "FlickCore", targets: ["FlickCore"]),
    ],
    targets: [
        .target(
            name: "FlickCore",
            path: "Sources/FlickCore",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("CoreServices"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
        .executableTarget(
            name: "Flick",
            dependencies: ["FlickCore"],
            path: "Sources/Flick",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "FlickSelfTest",
            dependencies: ["FlickCore"],
            path: "Sources/FlickSelfTest",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ],
    swiftLanguageModes: [.v5]
)

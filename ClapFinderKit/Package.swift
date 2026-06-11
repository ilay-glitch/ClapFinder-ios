// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClapFinderKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)   // required for swift build on macOS host
    ],
    products: [
        .library(name: "ClapFinderKitDesign", targets: ["ClapFinderKitDesign"]),
        .library(name: "ClapFinderKitAudio", targets: ["ClapFinderKitAudio"]),
        .library(name: "ClapFinderKitData", targets: ["ClapFinderKitData"]),
        .library(name: "ClapFinderKitAds", targets: ["ClapFinderKitAds"]),
        .library(name: "ClapFinderKitLocalization", targets: ["ClapFinderKitLocalization"])
    ],
    targets: [
        // Design tokens — the only module where hex color literals are permitted.
        .target(
            name: "ClapFinderKitDesign",
            path: "Sources/ClapFinderKitDesign"
        ),
        // Audio engine: clap detection, sound playback, flashlight, response coordination.
        .target(
            name: "ClapFinderKitAudio",
            dependencies: ["ClapFinderKitDesign", "ClapFinderKitData"],
            path: "Sources/ClapFinderKitAudio"
        ),
        // Data: Animal model, catalog, preferences, Sensitivity enum.
        .target(
            name: "ClapFinderKitData",
            dependencies: ["ClapFinderKitDesign"],
            path: "Sources/ClapFinderKitData",
            resources: [.process("Resources")]
        ),
        // Ad integration — stub in Phase 1, implemented in Phase 2.
        .target(
            name: "ClapFinderKitAds",
            dependencies: ["ClapFinderKitData"],
            path: "Sources/ClapFinderKitAds"
        ),
        // Localization helpers — stub for now.
        .target(
            name: "ClapFinderKitLocalization",
            path: "Sources/ClapFinderKitLocalization"
        ),
        .testTarget(
            name: "ClapFinderKitTests",
            dependencies: ["ClapFinderKitAds", "ClapFinderKitAudio", "ClapFinderKitData"],
            path: "Tests/ClapFinderKitTests"
        )
    ]
)

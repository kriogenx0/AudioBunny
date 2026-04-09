// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AudioBunny",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AudioBunny",
            path: "Sources/AudioBunny",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)

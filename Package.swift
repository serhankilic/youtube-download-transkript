// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "LocalTranscript",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "LocalTranscript",
            targets: ["LocalTranscript"]
        )
    ],
    targets: [
        .executableTarget(
            name: "LocalTranscript",
            path: ".",
            exclude: [
                "README.md",
                "design-system.html",
                "dist",
                "packaging",
                "scripts"
            ],
            sources: [
                "LocalTranscriptApp.swift",
                "Models.swift",
                "URLTextField.swift",
                "PythonLocator.swift",
                "BackendEnvironment.swift",
                "BackendInstaller.swift",
                "PythonRunner.swift",
                "DesignSystem.swift",
                "TranscriptionViewModel.swift",
                "LoadingStatusCard.swift",
                "SkeletonView.swift",
                "ContentView.swift"
            ],
            resources: [
                .copy("Backend")
            ]
        )
    ]
)

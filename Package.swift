// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Cribbage",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "CribbageCore"),
        .target(name: "CribbageUI", dependencies: ["CribbageCore"]),
        .executableTarget(name: "Cribbage", dependencies: ["CribbageCore", "CribbageUI"]),
        .executableTarget(name: "CribbageChecks", dependencies: ["CribbageCore"]),
    ],
    swiftLanguageModes: [.v5]
)

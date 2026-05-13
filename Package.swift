// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Loupe",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(name: "Loupe",     targets: ["Loupe"]),
        .library(name: "LoupeNoop", targets: ["LoupeNoop"]),
        .executable(name: "LoupeMacApp", targets: ["LoupeMacApp"]),
    ],
    targets: [
        .target(
            name: "Loupe",
            path: "Sources/Loupe",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .target(
            name: "LoupeNoop",
            path: "Sources/LoupeNoop"
        ),
        // macOS companion app — run with: swift run LoupeMacApp
        .executableTarget(
            name: "LoupeMacApp",
            path: "Sources/LoupeMacApp"
        ),
        .testTarget(
            name: "LoupeTests",
            dependencies: ["Loupe"],
            path: "Tests/LoupeTests"
        ),
    ]
)

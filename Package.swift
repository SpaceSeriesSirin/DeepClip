// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DeepClip",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DeepClip", targets: ["DeepClip"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0")
    ],
    targets: [
        .executableTarget(
            name: "DeepClip",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "DeepClipTests",
            dependencies: ["DeepClip"],
            path: "Tests/DeepClipTests"
        )
    ]
)

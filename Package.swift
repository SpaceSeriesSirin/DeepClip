// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipboardManager",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClipboardManager", targets: ["ClipboardManager"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ClipboardManager",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "ClipboardManagerTests",
            dependencies: ["ClipboardManager"],
            path: "Tests/ClipboardManagerTests"
        )
    ]
)

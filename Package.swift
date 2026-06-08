// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CacheMind",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CacheMind", targets: ["CacheMind"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0")
    ],
    targets: [
        .executableTarget(
            name: "CacheMind",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "CacheMindTests",
            dependencies: ["CacheMind"],
            path: "Tests/CacheMindTests"
        )
    ]
)

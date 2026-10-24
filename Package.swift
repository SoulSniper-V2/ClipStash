// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "ClipStash",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "ClipStash", targets: ["ClipStash"])],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.1"),
    ],
    targets: [
        .executableTarget(
            name: "ClipStash",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")],
            path: ".",
            exclude: [
                "ClipStash.xcodeproj", "ClipStash-V2.dmg", "ClipStash.entitlements",
                "LICENSE", "README.md", "project.yml", "Tests",
            ],
            sources: ["Sources"],
            // Keep assets usable on SwiftPM toolchains that do not compile catalogs.
            resources: [.copy("Resources/Assets.xcassets")]
        ),
        .testTarget(
            name: "ClipStashTests",
            dependencies: ["ClipStash", .product(name: "GRDB", package: "GRDB.swift")],
            path: "Tests/ClipStashTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)

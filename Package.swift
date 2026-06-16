// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Artisan",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ArtisanPrototypeApp", targets: ["ArtisanPrototypeApp"]),
        .executable(name: "artisan-proto", targets: ["artisan-proto"])
    ],
    targets: [
        .executableTarget(name: "ArtisanPrototypeApp"),
        .executableTarget(name: "artisan-proto")
    ]
)

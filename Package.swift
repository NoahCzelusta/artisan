// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Artisan",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ArtisanApp", targets: ["ArtisanApp"]),
        .executable(name: "artisan", targets: ["artisan"])
    ],
    targets: [
        .executableTarget(name: "ArtisanApp"),
        .executableTarget(name: "artisan")
    ]
)

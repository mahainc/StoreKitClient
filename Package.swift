// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StoreKitClient",
    platforms: [
        .iOS(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)
    ],
    products: [
        .singleTargetLibrary("StoreKitClient"),
        .singleTargetLibrary("StoreKitClientLive"),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies.git",
            from: "1.9.0"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-case-paths.git",
            from: "1.5.0"
        ),
    ],
    targets: [
        .target(
            name: "StoreKitClient",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "CasePaths", package: "swift-case-paths"),
            ]
        ),
        .target(
            name: "StoreKitClientLive",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                "StoreKitClient"
            ]
        ),
        .testTarget(
            name: "StoreKitClientTests",
            dependencies: [
                "StoreKitClient",
            ]
        ),
    ]
)

extension Product {
    static func singleTargetLibrary(_ name: String) -> Product {
        .library(name: name, targets: [name])
    }
}

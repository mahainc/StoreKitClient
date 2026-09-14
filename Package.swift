// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StoreKitClient",
    // Narrowed from iOS 16 / macOS 13 / tvOS / watchOS / visionOS: StoreKitClientLive
    // now carries the FunnelClient port conformer, and FunnelClient ships iOS 17 /
    // macOS 14 only. No consumer in the fleet builds this for tvOS, watchOS or visionOS.
    platforms: [
        .iOS(.v17), .macOS(.v14),
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
        // Pinned exactly, unlike the rest: StoreKitFunnelProvider conforms to
        // FunnelClient's StoreKit.Providing port, which moves in major versions.
        .package(
            url: "https://github.com/mahainc/FunnelClient.git",
            from: "7.0.0"
        ),
        .package(
            url: "https://github.com/mahainc/LogClient.git",
            from: "0.3.0"
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
        // The only target that knows FunnelClient exists. StoreKitClient itself stays a
        // plain StoreKit wrapper any consumer can use without the funnel.
        .target(
            name: "StoreKitClientLive",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "FunnelClient", package: "FunnelClient"),
                .product(name: "LogClient", package: "LogClient"),
                "StoreKitClient",
            ]
        ),
        .testTarget(
            name: "StoreKitClientTests",
            dependencies: [
                "StoreKitClient",
                "StoreKitClientLive",
            ]
        ),
    ]
)

extension Product {
    static func singleTargetLibrary(_ name: String) -> Product {
        .library(name: name, targets: [name])
    }
}

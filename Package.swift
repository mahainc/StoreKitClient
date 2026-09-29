// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StoreKitClient",
    // Narrowed from iOS 16 / macOS 13 / tvOS / watchOS / visionOS because the
    // funnel conformer needs FunnelClient, which ships iOS 17 / macOS 14 only.
    // Kept at that floor even with the trait off: no consumer in the fleet
    // builds this for tvOS, watchOS or visionOS.
    platforms: [
        .iOS(.v17), .macOS(.v14),
    ],
    products: [
        .singleTargetLibrary("StoreKitClient"),
        .singleTargetLibrary("StoreKitClientLive"),
    ],
    // The funnel conformer is opt-in. A consumer that never touches
    // `FunnelClient.StoreKit.Providing` should not pay for FunnelClient +
    // LogClient in its dependency graph — and, more to the point, should not
    // link the `UIDevice.identifierForVendor` read that the conformer's
    // consumable-credit path carries. `#if canImport(FunnelClient)` cannot do
    // this: it is evaluated after resolution, so the dependency is already
    // fetched and built by the time the compiler sees it. A trait gates the
    // edge itself.
    //
    // Off by default, so adding this package never widens a graph by surprise:
    //   .package(url: "…/StoreKitClient.git", from: "5.0.0")                  // no funnel
    //   .package(url: "…/StoreKitClient.git", from: "5.0.0", traits: ["Funnel"])
    traits: [
        .default(enabledTraits: []),
        Trait(
            name: "Funnel",
            description: "Conform StoreKitClient to FunnelClient's StoreKit port."
        ),
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
            from: "9.0.0"
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
        // The only target that knows FunnelClient exists, and only when the
        // `Funnel` trait is on. StoreKitClient itself stays a plain StoreKit
        // wrapper any consumer can use without the funnel.
        .target(
            name: "StoreKitClientLive",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(
                    name: "FunnelClient",
                    package: "FunnelClient",
                    condition: .when(traits: ["Funnel"])
                ),
                .product(
                    name: "LogClient",
                    package: "LogClient",
                    condition: .when(traits: ["Funnel"])
                ),
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

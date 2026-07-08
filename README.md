# StoreKitClient

A TCA-style dependency client wrapping StoreKit 2 for in-app purchases and subscription handling. Surfaces the StoreKit 2 async API behind a `@DependencyClient` interface, plus an `AsyncStream<TransactionEvent>` for live transaction observation.

## Layout

- **`StoreKitClient`** — interface: `loadProducts`, `purchase`, `restorePurchases`, `observeTransactions`, `getLatestTransaction`, `currentSubscriptionStatus`, `observeSubscriptionStatus`, `isEligibleForIntroOffer`, `processUnfinishedConsumables`, `canMakePayments`, `requestReview`, `receiptURL`, plus an `extension StoreKitClient.Product` value type with `priceFormatStyle` for localized currency display (added in 1.1.0). `currentSubscriptionStatus` / `observeSubscriptionStatus` (added in 1.2.0) surface expiration-aware `SubscriptionStatus` for detecting when a free trial or subscription lapses.
- **`StoreKitClientLive`** — `StoreKit` wrapper with an actor-backed transaction listener registry; registers the live `DependencyKey`.

## Installation

```swift
.package(url: "https://github.com/mahainc/StoreKitClient.git", from: "1.2.0"),
```

`StoreKitClient` on feature targets; `StoreKitClientLive` on the app target.

## Usage

```swift
import StoreKitClient
import ComposableArchitecture

@Reducer
struct PaywallFeature {
    @ObservableState
    struct State {
        var products: [StoreKitClient.Product] = []
        var isPurchasing: Bool = false
    }

    enum Action {
        case task
        case productsLoaded([StoreKitClient.Product])
        case purchaseTapped(productID: String)
        case purchaseCompleted(StoreKitClient.Transaction)
    }

    @Dependency(\.storeKitClient) var store

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { send in
                    let products = try await store.loadProducts(["com.app.weekly", "com.app.yearly"])
                    await send(.productsLoaded(products))
                }

            case .productsLoaded(let products):
                state.products = products
                return .none

            case .purchaseTapped(let productID):
                state.isPurchasing = true
                return .run { send in
                    let transaction = try await store.purchase(productID)
                    await send(.purchaseCompleted(transaction))
                }

            case .purchaseCompleted:
                state.isPurchasing = false
                return .none
            }
        }
    }
}
```

## Localized price formatting

```swift
// In a SwiftUI view:
Text(product.price, format: product.priceFormatStyle)
```

## Observing transactions at app launch

Hook `observeTransactions()` early in the app lifecycle to receive updates from purchases that complete outside the app (App Store sandbox, family sharing, refunds):

```swift
.task {
    for await event in await store.observeTransactions() {
        await handle(event)
    }
}
```

> **Note:** `observeTransactions()` does **not** fire when a subscription or free trial simply
> expires — StoreKit emits a `Transaction.updates` entry only for renewals, refunds, and
> revocations, never for a plain lapse. Use the subscription-status API below to detect trial end.

## Detecting when a free trial or subscription ends

`observeTransactions` reports `.removed` only on revocation (refunds, family-sharing removal). A
free trial that lapses without renewal produces no transaction event, so a boolean driven purely
off that stream stays stuck at "purchased". Use the expiration-aware status API instead:

```swift
// Live downgrade while the app is running:
.task {
    for await statuses in await store.observeSubscriptionStatus("premium_access") {
        let isActive = statuses.contains { premiumIDs.contains($0.productID) && $0.isActive }
        setPremium(isActive)
    }
}

// Cold-start / foreground re-check (no live event fires for an expiry that happened while closed):
let statuses = await store.currentSubscriptionStatus("premium_access")
setPremium(statuses.contains { premiumIDs.contains($0.productID) && $0.isActive })
```

`SubscriptionStatus.isActive` is `true` for `.subscribed`, `.inGracePeriod`, and
`.inBillingRetryPeriod`; `false` for `.expired`, `.revoked`, and `.unknown`.

## Testing

`@DependencyClient` generates unimplemented `testValue` defaults:

```swift
let store = TestStore(initialState: PaywallFeature.State()) {
    PaywallFeature()
} withDependencies: {
    $0.storeKitClient.loadProducts = { _ in [.mock] }
    $0.storeKitClient.purchase = { _ in .mockPurchased }
}
```

## Dependencies

- `swift-dependencies` from 1.9.0
- `swift-case-paths` from 1.5.0

## Platform support

- iOS 16+, macOS 13+, tvOS 16+, watchOS 9+, visionOS 1+

## License

MIT — see [LICENSE](./LICENSE).

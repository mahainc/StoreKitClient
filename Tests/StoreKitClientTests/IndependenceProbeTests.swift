//
//  IndependenceProbeTests.swift
//  StoreKitClient
//

import Dependencies
import StoreKitClient
import StoreKitClientLive
import XCTest

/// A consumer written against the StoreKit wrapper alone.
///
/// Nothing in this file imports FunnelClient or names a funnel type, and nothing uses
/// `@testable`: it compiles against the package's public API exactly as an unrelated app
/// would. If a change ever makes the wrapper unusable without the funnel, this file stops
/// compiling — which is the point of it.
@available(iOS 15.0, *)
private struct PlainStoreKitConsumer {
    let client: StoreKitClient

    func buyLifetimeUnlock(_ productID: String) async throws -> StoreKitClient.Transaction {
        try await client.purchase(productID)
    }

    func startSubscription(_ productID: String) async throws -> StoreKitClient.Transaction {
        try await client.subscribe(productID)
    }

    func restoreEverything() async -> [StoreKitClient.Transaction] {
        await client.restorePurchases()
    }

    func firstTransactionEvent() async -> StoreKitClient.TransactionEvent? {
        let stream = await client.observeTransactions()
        var events = stream.makeAsyncIterator()
        return await events.next()
    }
}

@available(iOS 15.0, *)
final class IndependenceProbeTests: XCTestCase {

    func testAConsumerWithNoFunnelDrivesEveryPurchasePath() async throws {
        let consumer = PlainStoreKitConsumer(client: .withActiveSubscription)

        let unlock = try await consumer.buyLifetimeUnlock("com.example.unlock")
        XCTAssertFalse(unlock.productID.isEmpty)

        let subscription = try await consumer.startSubscription("com.example.premium")
        XCTAssertEqual(subscription.productType, .autoRenewable)

        let restored = await consumer.restoreEverything()
        XCTAssertEqual(restored.count, 1)
    }

    func testAConsumerWithNoFunnelObservesTransactions() async {
        let consumer = PlainStoreKitConsumer(client: .withTransactionUpdates)

        let event = await consumer.firstTransactionEvent()

        guard case .updated = event else {
            return XCTFail("Expected an .updated event, got \(String(describing: event))")
        }
    }

    /// The live implementation must be reachable from those two imports alone.
    ///
    /// Only the conformance is checked: touching `liveValue` would wake a real StoreKit actor
    /// and a `Transaction.updates` loop inside a unit test.
    func testTheLiveModuleSuppliesTheDependencyKeyConformance() {
        XCTAssertTrue(conformsToDependencyKey(StoreKitClient.self))
    }
}

@available(iOS 15.0, *)
private func conformsToDependencyKey<Key: DependencyKey>(_ type: Key.Type) -> Bool {
    true
}

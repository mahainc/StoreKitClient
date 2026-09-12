//
//  ClientContractTests.swift
//  StoreKitClient
//

import Dependencies
import Foundation
import XCTest

@testable import StoreKitClient

/// Contracts a consumer may rely on across every shipped client, live or mock.
@available(iOS 15.0, *)
final class ClientContractTests: XCTestCase {

    private struct VerifierRefused: Swift.Error {}

    /// A `verify` that throws must reach the caller.
    ///
    /// It is the signal that the grant was not recorded, and the reason the live path leaves
    /// the transaction unfinished. A mock that swallowed it would let a consumer's own tests
    /// pass over a bug that costs a user a paid grant in production.
    func testAVerifyFailureReachesTheCallerOfPurchaseConsumable() async {
        let clients: [(String, StoreKitClient)] = [
            ("noop", .noop),
            ("failing", .failing),
            ("happy", .happy),
            ("withActiveSubscription", .withActiveSubscription),
            ("withExpiredSubscription", .withExpiredSubscription),
            ("withConsumables", .withConsumables),
            ("withTransactionUpdates", .withTransactionUpdates),
        ]

        for (name, client) in clients {
            do {
                _ = try await client.purchaseConsumable("com.example.coins100", nil) { _ in
                    throw VerifierRefused()
                }
                XCTFail("\(name) swallowed the verifier's failure")
            } catch {
                XCTAssertTrue(error is VerifierRefused, "\(name) reported \(error)")
            }
        }
    }

    /// The verified transaction is handed to `verify` before it is handed back to the caller.
    func testTheVerifierSeesTheTransactionThatIsReturned() async throws {
        let client = StoreKitClient.withConsumables
        let seen = TransactionBox()

        let returned = try await client.purchaseConsumable("com.example.coins100", nil) { transaction in
            seen.store(transaction)
        }

        XCTAssertEqual(seen.value, returned)
    }

    /// A failed App Store sync throws rather than reporting an empty restore.
    ///
    /// "We could not ask" and "you own nothing" lead to opposite user-facing behaviour, which
    /// is why the sync is its own throwing endpoint instead of a step folded into
    /// `restorePurchases`.
    func testSyncAppStoreSurfacesFailureWhileRestoreStaysQuiet() async {
        await withDependencies {
            $0.storeKitClient = .failing
        } operation: {
            @Dependency(\.storeKitClient) var client
            do {
                try await client.syncAppStore()
                XCTFail("Expected syncAppStore to throw")
            } catch {
                XCTAssertTrue(error is URLError)
            }
            let restored = await client.restorePurchases()
            XCTAssertTrue(restored.isEmpty)
        }
    }

    func testSyncAppStoreSucceedsOnTheHappyClient() async throws {
        try await withDependencies {
            $0.storeKitClient = .happy
        } operation: {
            @Dependency(\.storeKitClient) var client
            try await client.syncAppStore()
        }
    }

    /// Each mock's `subscribe` answers with a subscription, not with whatever `purchase` sells.
    func testSubscribeAnswersWithASubscriptionAcrossTheMocks() async throws {
        let clients: [(String, StoreKitClient)] = [
            ("happy", .happy),
            ("withActiveSubscription", .withActiveSubscription),
            ("withConsumables", .withConsumables),
            ("withTransactionUpdates", .withTransactionUpdates),
        ]

        for (name, client) in clients {
            let transaction = try await client.subscribe("com.example.product.weekly")
            XCTAssertEqual(transaction.productType, .autoRenewable, "\(name)")
        }
    }

    func testFailingClientRefusesToSubscribe() async {
        do {
            _ = try await StoreKitClient.failing.subscribe("com.example.product.weekly")
            XCTFail("Expected subscribe to throw")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }
}

/// Carries a transaction out of the `@Sendable` verifier closure.
@available(iOS 15.0, *)
private final class TransactionBox: @unchecked Sendable {
    private var stored: StoreKitClient.Transaction?
    private let lock = NSLock()

    var value: StoreKitClient.Transaction? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func store(_ transaction: StoreKitClient.Transaction) {
        lock.lock()
        stored = transaction
        lock.unlock()
    }
}

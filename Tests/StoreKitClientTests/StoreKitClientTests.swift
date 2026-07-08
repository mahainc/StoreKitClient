//
//  StoreKitClientTests.swift
//  StoreKitClient
//
//  Created on 17/11/25.
//

import Dependencies
import XCTest

@testable import StoreKitClient

private final class CallCounter: @unchecked Sendable {
    private var _count = 0
    private let lock = NSLock()
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }
    func increment() {
        lock.lock()
        _count += 1
        lock.unlock()
    }
}

@available(iOS 15.0, *)
final class StoreKitClientTests: XCTestCase {

    // MARK: - Product Model Tests

    func testProductInit() {
        let product = StoreKitClient.Product(
            id: "com.test.weekly",
            displayName: "Weekly",
            description: "Weekly subscription",
            price: 0.99,
            displayPrice: "$0.99",
            type: .autoRenewable,
            subscription: .init(
                subscriptionPeriod: .init(unit: .week, value: 1),
                subscriptionGroupID: "group1"
            )
        )

        XCTAssertEqual(product.id, "com.test.weekly")
        XCTAssertEqual(product.displayName, "Weekly")
        XCTAssertEqual(product.description, "Weekly subscription")
        XCTAssertEqual(product.price, 0.99)
        XCTAssertEqual(product.displayPrice, "$0.99")
        XCTAssertEqual(product.type, .autoRenewable)
        XCTAssertNotNil(product.subscription)
        XCTAssertEqual(product.subscription?.subscriptionGroupID, "group1")
    }

    func testProductWithoutSubscription() {
        let product = StoreKitClient.Product(
            id: "com.test.coins",
            displayName: "Coins",
            description: "100 coins",
            price: 0.99,
            displayPrice: "$0.99",
            type: .consumable
        )

        XCTAssertNil(product.subscription)
    }

    // MARK: - SubscriptionPeriod Tests

    func testSubscriptionPeriodDisplayDescription() {
        let cases: [(StoreKitClient.SubscriptionPeriod, String)] = [
            (.init(unit: .day, value: 1), "1 day"),
            (.init(unit: .day, value: 3), "3 days"),
            (.init(unit: .week, value: 1), "1 week"),
            (.init(unit: .week, value: 2), "2 weeks"),
            (.init(unit: .month, value: 1), "1 month"),
            (.init(unit: .month, value: 6), "6 months"),
            (.init(unit: .year, value: 1), "1 year"),
            (.init(unit: .year, value: 2), "2 years"),
        ]

        for (period, expected) in cases {
            XCTAssertEqual(period.displayDescription, expected, "Failed for \(period.unit) x \(period.value)")
        }
    }

    // MARK: - SubscriptionOffer Tests

    func testSubscriptionOfferFreeTrial() {
        let offer = StoreKitClient.SubscriptionOffer(
            type: .introductory,
            period: .init(unit: .day, value: 3),
            periodCount: 1,
            price: 0,
            displayPrice: "Free",
            paymentMode: .freeTrial
        )

        XCTAssertTrue(offer.isFreeTrial)
        XCTAssertEqual(offer.displayDescription, "3 days free trial")
    }

    func testSubscriptionOfferPayUpFront() {
        let offer = StoreKitClient.SubscriptionOffer(
            type: .introductory,
            period: .init(unit: .month, value: 1),
            periodCount: 1,
            price: 0.49,
            displayPrice: "$0.49",
            paymentMode: .payUpFront
        )

        XCTAssertFalse(offer.isFreeTrial)
        XCTAssertEqual(offer.displayDescription, "$0.49 for 1 month")
    }

    func testSubscriptionOfferPayAsYouGo() {
        let offer = StoreKitClient.SubscriptionOffer(
            type: .promotional,
            period: .init(unit: .month, value: 1),
            periodCount: 3,
            price: 0.99,
            displayPrice: "$0.99",
            paymentMode: .payAsYouGo
        )

        XCTAssertFalse(offer.isFreeTrial)
        XCTAssertEqual(offer.displayDescription, "$0.99/month for 3 months")
    }

    // MARK: - Transaction Tests

    func testTransactionNilRawValueDefaults() {
        let transaction = StoreKitClient.Transaction(rawValue: nil)

        XCTAssertEqual(transaction.id, 0)
        XCTAssertEqual(transaction.productID, "")
        XCTAssertEqual(transaction.productType, .nonConsumable)
        XCTAssertNil(transaction.purchaseDate)
        XCTAssertNil(transaction.expirationDate)
        XCTAssertEqual(transaction.purchasedQuantity, 1)
        XCTAssertNil(transaction.offerType)
        XCTAssertNil(transaction.offerID)
        XCTAssertFalse(transaction.isFreeTrial)
        XCTAssertFalse(transaction.isExpired)
        XCTAssertEqual(transaction.environment, .unknown)
        XCTAssertEqual(transaction.displayPrice, "Unknown Price")
    }

    func testStaticMockTransactionsAreNilBacked() {
        XCTAssertNil(StoreKitClient.Transaction.mockConsumable.rawValue)
        XCTAssertNil(StoreKitClient.Transaction.mockSubscription.rawValue)
        XCTAssertNil(StoreKitClient.Transaction.mockExpiredSubscription.rawValue)
    }

    // MARK: - SubscriptionStatus Tests

    func testSubscriptionStatusIsActive() {
        let cases: [(StoreKitClient.SubscriptionStatus.RenewalState, Bool)] = [
            (.subscribed, true),
            (.inGracePeriod, true),
            (.inBillingRetryPeriod, true),
            (.expired, false),
            (.revoked, false),
            (.unknown, false),
        ]

        for (state, expectedActive) in cases {
            let status = StoreKitClient.SubscriptionStatus(
                state: state,
                productID: "com.test.weekly",
                groupID: "premium_access"
            )
            XCTAssertEqual(status.isActive, expectedActive, "Failed for state \(state)")
        }
    }

    func testWithExpiredSubscriptionStatusIsNotActive() async {
        await withDependencies {
            $0.storeKitClient = .withExpiredSubscription
        } operation: {
            @Dependency(\.storeKitClient) var client
            let statuses = await client.currentSubscriptionStatus("premium_access")
            XCTAssertEqual(statuses.count, 1)
            XCTAssertEqual(statuses.first?.state, .expired)
            XCTAssertEqual(statuses.first?.isActive, false)
        }
    }

    func testWithActiveSubscriptionStatusIsActive() async {
        await withDependencies {
            $0.storeKitClient = .withActiveSubscription
        } operation: {
            @Dependency(\.storeKitClient) var client
            let statuses = await client.currentSubscriptionStatus("premium_access")
            XCTAssertEqual(statuses.first?.isActive, true)
        }
    }

    func testWithExpiredSubscriptionStreamEmitsExpired() async {
        await withDependencies {
            $0.storeKitClient = .withExpiredSubscription
        } operation: {
            @Dependency(\.storeKitClient) var client
            let stream = await client.observeSubscriptionStatus("premium_access")
            var received: [StoreKitClient.SubscriptionStatus] = []
            for await statuses in stream {
                received = statuses
            }
            XCTAssertEqual(received.first?.isActive, false)
        }
    }

    // MARK: - TransactionEnvironment Tests

    func testTransactionEnvironmentRawValues() {
        XCTAssertEqual(StoreKitClient.TransactionEnvironment.sandbox.rawValue, "sandbox")
        XCTAssertEqual(StoreKitClient.TransactionEnvironment.production.rawValue, "production")
        XCTAssertEqual(StoreKitClient.TransactionEnvironment.xcode.rawValue, "xcode")
        XCTAssertEqual(StoreKitClient.TransactionEnvironment.unknown.rawValue, "unknown")
    }

    // MARK: - Happy Mock Tests

    func testHappyCanMakePayments() async {
        await withDependencies {
            $0.storeKitClient = .happy
        } operation: {
            @Dependency(\.storeKitClient) var client
            XCTAssertTrue(client.canMakePayments())
        }
    }

    func testHappyLoadProducts() async throws {
        try await withDependencies {
            $0.storeKitClient = .happy
        } operation: {
            @Dependency(\.storeKitClient) var client
            let products = try await client.loadProducts(["any"])

            XCTAssertEqual(products.count, 3)
            XCTAssertTrue(products.allSatisfy { $0.type == .autoRenewable })
        }
    }

    func testHappyWeeklyHasFreeTrial() async throws {
        try await withDependencies {
            $0.storeKitClient = .happy
        } operation: {
            @Dependency(\.storeKitClient) var client
            let products = try await client.loadProducts(["any"])

            let weekly = products.first { $0.id == "com.example.product.weekly" }
            XCTAssertNotNil(weekly)
            XCTAssertNotNil(weekly?.subscription?.introductoryOffer)
            XCTAssertEqual(weekly?.subscription?.introductoryOffer?.isFreeTrial, true)
            XCTAssertEqual(weekly?.subscription?.introductoryOffer?.period.unit, .day)
            XCTAssertEqual(weekly?.subscription?.introductoryOffer?.period.value, 3)
            XCTAssertEqual(weekly?.subscription?.subscriptionGroupID, "premium_access")
        }
    }

    func testHappyMonthlyNoIntroOffer() async throws {
        try await withDependencies {
            $0.storeKitClient = .happy
        } operation: {
            @Dependency(\.storeKitClient) var client
            let products = try await client.loadProducts(["any"])

            let monthly = products.first { $0.id == "com.example.product.monthly" }
            XCTAssertNotNil(monthly)
            XCTAssertNil(monthly?.subscription?.introductoryOffer)
            XCTAssertEqual(monthly?.subscription?.subscriptionPeriod.unit, .month)
        }
    }

    func testHappyPurchaseSucceeds() async throws {
        try await withDependencies {
            $0.storeKitClient = .happy
        } operation: {
            @Dependency(\.storeKitClient) var client
            let transaction = try await client.purchase("com.example.product.weekly")
            // Mock returns Transaction(rawValue: nil), so we just verify no throw
            XCTAssertNil(transaction.rawValue)
        }
    }

    func testHappyIntroOfferEligible() async {
        await withDependencies {
            $0.storeKitClient = .happy
        } operation: {
            @Dependency(\.storeKitClient) var client
            let eligible = await client.isEligibleForIntroOffer("premium_access")
            XCTAssertTrue(eligible)
        }
    }

    func testHappyGetLatestTransaction() async {
        await withDependencies {
            $0.storeKitClient = .happy
        } operation: {
            @Dependency(\.storeKitClient) var client
            let transaction = await client.getLatestTransaction()
            XCTAssertNotNil(transaction)
        }
    }

    // MARK: - Failing Mock Tests

    func testFailingLoadProductsThrows() async {
        await withDependencies {
            $0.storeKitClient = .failing
        } operation: {
            @Dependency(\.storeKitClient) var client
            do {
                _ = try await client.loadProducts(["any"])
                XCTFail("Expected loadProducts to throw")
            } catch {
                XCTAssertTrue(error is URLError)
            }
        }
    }

    func testFailingPurchaseThrows() async {
        await withDependencies {
            $0.storeKitClient = .failing
        } operation: {
            @Dependency(\.storeKitClient) var client
            do {
                _ = try await client.purchase("any")
                XCTFail("Expected purchase to throw")
            } catch {
                XCTAssertTrue(error is URLError)
            }
        }
    }

    // MARK: - Noop Mock Tests

    func testNoopCannotMakePayments() async {
        await withDependencies {
            $0.storeKitClient = .noop
        } operation: {
            @Dependency(\.storeKitClient) var client
            XCTAssertFalse(client.canMakePayments())
        }
    }

    // MARK: - WithActiveSubscription Mock Tests

    func testWithActiveSubscriptionRestore() async {
        await withDependencies {
            $0.storeKitClient = .withActiveSubscription
        } operation: {
            @Dependency(\.storeKitClient) var client
            let restored = await client.restorePurchases()
            XCTAssertEqual(restored.count, 1)
        }
    }

    func testWithActiveSubscriptionNotEligibleForIntro() async {
        await withDependencies {
            $0.storeKitClient = .withActiveSubscription
        } operation: {
            @Dependency(\.storeKitClient) var client
            let eligible = await client.isEligibleForIntroOffer("premium_access")
            XCTAssertFalse(eligible)
        }
    }

    // MARK: - WithConsumables Mock Tests

    func testWithConsumablesProcess() async {
        await withDependencies {
            $0.storeKitClient = .withConsumables
        } operation: {
            @Dependency(\.storeKitClient) var client
            let counter = CallCounter()
            await client.processUnfinishedConsumables { _ in
                counter.increment()
            }
            XCTAssertEqual(counter.count, 1)
        }
    }

    // MARK: - WithTransactionUpdates Mock Tests

    func testWithTransactionUpdatesStream() async {
        await withDependencies {
            $0.storeKitClient = .withTransactionUpdates
        } operation: {
            @Dependency(\.storeKitClient) var client
            let stream = await client.observeTransactions()
            var events: [StoreKitClient.TransactionEvent] = []
            for await event in stream {
                events.append(event)
            }
            XCTAssertEqual(events.count, 2)
        }
    }

    // MARK: - Error Tests

    func testErrorDescriptions() {
        let errors: [StoreKitClient.Error] = [
            .fetchProductsFailed(productIDs: ["id1"], underlyingError: URLError(.badServerResponse)),
            .unverifiedTransaction(URLError(.unknown)),
            .userCancelled,
            .purchasePending,
            .unknownPurchaseResult,
            .productNotFound(productID: "missing"),
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Missing description for \(error)")
        }
    }

    func testUserCancelledNoRecoverySuggestion() {
        let error = StoreKitClient.Error.userCancelled
        XCTAssertNil(error.recoverySuggestion)
    }

    func testProductNotFoundRecoverySuggestion() {
        let error = StoreKitClient.Error.productNotFound(productID: "missing")
        XCTAssertNotNil(error.recoverySuggestion)
    }
}

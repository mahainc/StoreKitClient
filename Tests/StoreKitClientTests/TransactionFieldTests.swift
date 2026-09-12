//
//  TransactionFieldTests.swift
//  StoreKitClient
//

import StoreKit
import XCTest

@testable import StoreKitClient

/// What a transaction reports when StoreKit is not behind it.
///
/// A `nil`-backed transaction used to answer `0` for `id` and `""` for `productID`, which made
/// two mocks indistinguishable and left every flow keyed on a product or a transaction
/// identifier — the credit path above all — untestable.
@available(iOS 15.0, *)
final class TransactionFieldTests: XCTestCase {

    func testNilBackedTransactionStillReportsNothingForTheNewFields() {
        let transaction = StoreKitClient.Transaction(rawValue: nil)

        XCTAssertNil(transaction.originalID)
        XCTAssertNil(transaction.price)
        XCTAssertNil(transaction.currency)
        XCTAssertNil(transaction.salesRegion)
        XCTAssertNil(transaction.ownershipType)
    }

    func testCarriedFieldsAreReportedBack() {
        let purchased = Date(timeIntervalSince1970: 1_700_000_000)
        let expires = Date(timeIntervalSince1970: 1_700_604_800)
        let transaction = StoreKitClient.Transaction(
            id: 42,
            productID: "com.example.coins100",
            productType: .consumable,
            originalID: 41,
            purchaseDate: purchased,
            expirationDate: expires,
            purchasedQuantity: 3,
            offerType: .introductory,
            offerID: "offer-1",
            environment: .sandbox,
            price: 4.99,
            currency: "USD",
            salesRegion: "USA",
            ownershipType: .familyShared
        )

        XCTAssertNil(transaction.rawValue)
        XCTAssertEqual(transaction.id, 42)
        XCTAssertEqual(transaction.originalID, 41)
        XCTAssertEqual(transaction.productID, "com.example.coins100")
        XCTAssertEqual(transaction.productType, .consumable)
        XCTAssertEqual(transaction.purchaseDate, purchased)
        XCTAssertEqual(transaction.expirationDate, expires)
        XCTAssertEqual(transaction.purchasedQuantity, 3)
        XCTAssertEqual(transaction.offerType, .introductory)
        XCTAssertEqual(transaction.offerID, "offer-1")
        XCTAssertTrue(transaction.isFreeTrial)
        XCTAssertEqual(transaction.environment, .sandbox)
        XCTAssertEqual(transaction.price, 4.99)
        XCTAssertEqual(transaction.currency, "USD")
        XCTAssertEqual(transaction.salesRegion, "USA")
        XCTAssertEqual(transaction.ownershipType, .familyShared)
    }

    func testFieldsLeftOutKeepTheDefaultsNilBackedTransactionsAlwaysHad() {
        let transaction = StoreKitClient.Transaction(
            id: 7,
            productID: "com.example.unlock",
            productType: .nonConsumable
        )

        XCTAssertNil(transaction.originalID)
        XCTAssertNil(transaction.purchaseDate)
        XCTAssertEqual(transaction.purchasedQuantity, 1)
        XCTAssertEqual(transaction.environment, .unknown)
        XCTAssertFalse(transaction.isExpired)
        XCTAssertEqual(transaction.displayPrice, "Unknown Price")
    }

    func testStaticMocksAreTellableApart() {
        let consumable = StoreKitClient.Transaction.mockConsumable
        let active = StoreKitClient.Transaction.mockSubscription
        let expired = StoreKitClient.Transaction.mockExpiredSubscription

        XCTAssertEqual(Set([consumable.id, active.id, expired.id]).count, 3)
        XCTAssertNotEqual(consumable, active)
        XCTAssertNotEqual(active, expired)
        XCTAssertEqual(consumable.productID, "com.example.coins100")
        XCTAssertEqual(consumable.productType, .consumable)
        XCTAssertEqual(active.productType, .autoRenewable)
        XCTAssertEqual(consumable.price, 0.99)
        XCTAssertEqual(consumable.currency, "USD")
    }

    func testMockSubscriptionIsLiveAndTheExpiredOneIsNot() {
        XCTAssertFalse(StoreKitClient.Transaction.mockSubscription.isExpired)
        XCTAssertTrue(StoreKitClient.Transaction.mockExpiredSubscription.isExpired)
    }

    func testDisplayPriceComesFromTheCarriedPrice() {
        let transaction = StoreKitClient.Transaction(
            id: 1,
            productID: "com.example.coins100",
            productType: .consumable,
            price: 0.99,
            currency: "USD"
        )

        // The exact string is the formatter's and the test runner's locale to decide; that it
        // is no longer "Unknown Price" is the behaviour under test.
        XCTAssertNotNil(transaction.displayPrice)
        XCTAssertNotEqual(transaction.displayPrice, "Unknown Price")
    }
}

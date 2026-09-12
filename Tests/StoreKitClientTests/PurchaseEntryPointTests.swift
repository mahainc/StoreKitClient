//
//  PurchaseEntryPointTests.swift
//  StoreKitClient
//

import StoreKit
import XCTest

@testable import StoreKitClient
@testable import StoreKitClientLive

/// The rule the three purchase entry points share.
///
/// StoreKit has four product types and they are not interchangeable: only a consumable may
/// hold `finish()` back behind a server verify, and only a subscription lapses on its own. The
/// product's real type therefore decides which entry point may sell it, so a paywall wired to
/// the wrong SKU fails on the first tap instead of taking money for the wrong thing.
@available(iOS 15.0, *)
final class PurchaseEntryPointTests: XCTestCase {

    private let everyProductType: [StoreKit.Product.ProductType] = [
        .consumable,
        .nonConsumable,
        .autoRenewable,
        .nonRenewable,
    ]

    func testPurchaseServesOnlyNonConsumables() {
        assertEntryPoint(
            accepting: PurchaseEntryPoint.nonConsumable,
            expected: .nonConsumable,
            serves: [.nonConsumable]
        )
    }

    func testSubscribeServesBothSubscriptionTypes() {
        assertEntryPoint(
            accepting: PurchaseEntryPoint.subscription,
            expected: .autoRenewable,
            serves: [.autoRenewable, .nonRenewable]
        )
    }

    func testPurchaseConsumableServesOnlyConsumables() {
        assertEntryPoint(
            accepting: PurchaseEntryPoint.consumable,
            expected: .consumable,
            serves: [.consumable]
        )
    }

    func testMismatchNamesTheProductAndBothTypes() {
        XCTAssertThrowsError(
            try requireProductType(
                .autoRenewable,
                productID: "com.example.coins100",
                accepting: PurchaseEntryPoint.consumable,
                expected: .consumable
            )
        ) { error in
            guard
                let storeError = error as? StoreKitClient.Error,
                case .productTypeMismatch(let productID, let expected, let actual) = storeError
            else {
                XCTFail("Expected productTypeMismatch, got \(error)")
                return
            }
            XCTAssertEqual(productID, "com.example.coins100")
            XCTAssertEqual(expected, .consumable)
            XCTAssertEqual(actual, .autoRenewable)
        }
    }

    private func assertEntryPoint(
        accepting: Set<StoreKit.Product.ProductType>,
        expected: StoreKit.Product.ProductType,
        serves: Set<StoreKit.Product.ProductType>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for productType in everyProductType {
            let call = {
                try requireProductType(
                    productType,
                    productID: "com.example.any",
                    accepting: accepting,
                    expected: expected
                )
            }
            if serves.contains(productType) {
                XCTAssertNoThrow(try call(), "\(productType) should be served", file: file, line: line)
            } else {
                XCTAssertThrowsError(try call(), "\(productType) should be rejected", file: file, line: line)
            }
        }
    }
}

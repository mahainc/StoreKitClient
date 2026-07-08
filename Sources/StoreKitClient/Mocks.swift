//
//  Mocks.swift
//  StoreKitClient
//
//  Created by Thanh Hai Khong on 27/3/25.
//

import Dependencies
import Foundation

// MARK: - Constants

private enum MockConstants {
    /// Mock purchase delay in nanoseconds (5ms) - simulates network latency
    static let purchaseDelayNanoseconds: UInt64 = 5_000_000

    /// Transaction update delay in nanoseconds (100ms) - simulates async updates
    static let transactionUpdateDelayNanoseconds: UInt64 = 100_000_000
}

@available(iOS 15.0, *)
extension DependencyValues {
    public var storeKitClient: StoreKitClient {
        get { self[StoreKitClient.self] }
        set { self[StoreKitClient.self] = newValue }
    }
}

@available(iOS 15.0, *)
extension StoreKitClient: TestDependencyKey {
    public static let previewValue = Self.happy
    public static let testValue = Self()
}

@available(iOS 15.0, *)
extension StoreKitClient {
    /// A no-op implementation that performs no actions.
    ///
    /// Useful for tests where you want to ensure no StoreKit operations occur.
    public static let noop = Self(
        receiptURL: { nil },
        canMakePayments: { false },
        loadProducts: { _ in try await Task.never() },
        processUnfinishedConsumables: { _ in },
        observeTransactions: { .never },
        requestReview: {},
        purchase: { _ in
            .init(rawValue: nil)
        },
        restorePurchases: { [] },
        getLatestTransaction: { nil },
        isEligibleForIntroOffer: { _ in false },
        currentSubscriptionStatus: { _ in [] },
        observeSubscriptionStatus: { _ in .finished }
    )

    /// A failing implementation that throws errors for operations.
    ///
    /// Useful for testing error handling paths in your code.
    public static let failing = Self(
        receiptURL: { nil },
        canMakePayments: { false },
        loadProducts: { _ in throw URLError(.badServerResponse) },
        processUnfinishedConsumables: { _ in },
        observeTransactions: { .never },
        requestReview: {},
        purchase: { _ in
            throw URLError(.badServerResponse)
        },
        restorePurchases: { [] },
        getLatestTransaction: { nil },
        isEligibleForIntroOffer: { _ in false },
        currentSubscriptionStatus: { _ in [] },
        observeSubscriptionStatus: { _ in .finished }
    )

    /// A successful implementation with mock products and transactions.
    ///
    /// Returns three mock subscription products (weekly with 3-day trial, monthly, yearly)
    /// and simulates successful purchases with a small delay.
    public static let happy = Self(
        receiptURL: { nil },
        canMakePayments: { true },
        loadProducts: { _ in
            let products: [StoreKitClient.Product] = [
                .init(
                    id: "com.example.product.weekly",
                    displayName: "Weekly",
                    description: "Best Offer",
                    price: 0.99,
                    displayPrice: "$0.99",
                    type: .autoRenewable,
                    subscription: .init(
                        subscriptionPeriod: .init(unit: .week, value: 1),
                        introductoryOffer: .init(
                            type: .introductory,
                            period: .init(unit: .day, value: 3),
                            periodCount: 1,
                            price: 0,
                            displayPrice: "Free",
                            paymentMode: .freeTrial
                        ),
                        subscriptionGroupID: "premium_access"
                    )
                ),
                .init(
                    id: "com.example.product.monthly",
                    displayName: "Monthly",
                    description: "Best Value",
                    price: 1.99,
                    displayPrice: "$1.99",
                    type: .autoRenewable,
                    subscription: .init(
                        subscriptionPeriod: .init(unit: .month, value: 1),
                        subscriptionGroupID: "premium_access"
                    )
                ),
                .init(
                    id: "com.example.product.yearly",
                    displayName: "Yearly",
                    description: "Best Deal",
                    price: 9.99,
                    displayPrice: "$9.99",
                    type: .autoRenewable,
                    subscription: .init(
                        subscriptionPeriod: .init(unit: .year, value: 1),
                        subscriptionGroupID: "premium_access"
                    )
                ),
            ]
            return products
        },
        processUnfinishedConsumables: { _ in },
        observeTransactions: { .never },
        requestReview: {},
        purchase: { _ in
            try await Task.sleep(nanoseconds: MockConstants.purchaseDelayNanoseconds)
            return .init(rawValue: nil)
        },
        restorePurchases: { [] },
        getLatestTransaction: { .mockSubscription },
        isEligibleForIntroOffer: { _ in true },
        currentSubscriptionStatus: { groupID in
            [.init(state: .subscribed, productID: "com.example.product.weekly", groupID: groupID)]
        },
        observeSubscriptionStatus: { groupID in
            AsyncStream { continuation in
                continuation.yield([
                    .init(state: .subscribed, productID: "com.example.product.weekly", groupID: groupID)
                ])
                continuation.finish()
            }
        }
    )

    /// A mock with active subscription restoration.
    ///
    /// Simulates a user with an active subscription that can be restored.
    /// Not eligible for intro offer (already subscribed).
    public static let withActiveSubscription = Self(
        receiptURL: { nil },
        canMakePayments: { true },
        loadProducts: { _ in
            [
                .init(
                    id: "com.example.premium",
                    displayName: "Premium",
                    description: "Premium subscription",
                    price: 9.99,
                    displayPrice: "$9.99",
                    type: .autoRenewable,
                    subscription: .init(
                        subscriptionPeriod: .init(unit: .week, value: 1),
                        subscriptionGroupID: "premium_access"
                    )
                )
            ]
        },
        processUnfinishedConsumables: { _ in },
        observeTransactions: { .never },
        requestReview: {},
        purchase: { _ in .mockSubscription },
        restorePurchases: { [.mockSubscription] },
        getLatestTransaction: { .mockSubscription },
        isEligibleForIntroOffer: { _ in false },
        currentSubscriptionStatus: { groupID in
            [.init(state: .subscribed, productID: "com.example.premium", groupID: groupID)]
        },
        observeSubscriptionStatus: { groupID in
            AsyncStream { continuation in
                continuation.yield([.init(state: .subscribed, productID: "com.example.premium", groupID: groupID)])
                continuation.finish()
            }
        }
    )

    /// A mock with an expired subscription (e.g. a free trial that lapsed).
    ///
    /// Reports an `.expired` status (`isActive == false`) so consumers can verify they
    /// downgrade the user when a trial ends. Not eligible for a new intro offer.
    public static let withExpiredSubscription = Self(
        receiptURL: { nil },
        canMakePayments: { true },
        loadProducts: { _ in
            [
                .init(
                    id: "com.example.premium",
                    displayName: "Premium",
                    description: "Premium subscription",
                    price: 9.99,
                    displayPrice: "$9.99",
                    type: .autoRenewable,
                    subscription: .init(
                        subscriptionPeriod: .init(unit: .week, value: 1),
                        subscriptionGroupID: "premium_access"
                    )
                )
            ]
        },
        processUnfinishedConsumables: { _ in },
        observeTransactions: { .never },
        requestReview: {},
        purchase: { _ in .mockExpiredSubscription },
        restorePurchases: { [] },
        getLatestTransaction: { nil },
        isEligibleForIntroOffer: { _ in false },
        currentSubscriptionStatus: { groupID in
            [.init(state: .expired, productID: "com.example.premium", groupID: groupID)]
        },
        observeSubscriptionStatus: { groupID in
            AsyncStream { continuation in
                continuation.yield([.init(state: .expired, productID: "com.example.premium", groupID: groupID)])
                continuation.finish()
            }
        }
    )

    /// A mock that simulates consumable purchases.
    ///
    /// Includes unfinished consumables for testing delivery flows.
    public static let withConsumables = Self(
        receiptURL: { nil },
        canMakePayments: { true },
        loadProducts: { _ in
            [
                .init(
                    id: "com.example.coins100",
                    displayName: "100 Coins",
                    description: "100 game coins",
                    price: 0.99,
                    displayPrice: "$0.99",
                    type: .consumable
                )
            ]
        },
        processUnfinishedConsumables: { handler in
            try? await handler(.mockConsumable)
        },
        observeTransactions: { .never },
        requestReview: {},
        purchase: { _ in .mockConsumable },
        restorePurchases: { [] },
        getLatestTransaction: { nil },
        isEligibleForIntroOffer: { _ in false },
        currentSubscriptionStatus: { _ in [] },
        observeSubscriptionStatus: { _ in .finished }
    )

    /// A mock that emits transaction updates.
    ///
    /// Simulates the transaction observation stream with updates.
    public static let withTransactionUpdates = Self(
        receiptURL: { nil },
        canMakePayments: { true },
        loadProducts: { _ in [] },
        processUnfinishedConsumables: { _ in },
        observeTransactions: {
            AsyncStream { continuation in
                Task {
                    try? await Task.sleep(nanoseconds: MockConstants.transactionUpdateDelayNanoseconds)
                    continuation.yield(.updated(.mockSubscription))
                    try? await Task.sleep(nanoseconds: MockConstants.transactionUpdateDelayNanoseconds)
                    continuation.yield(.updated(.mockConsumable))
                    continuation.finish()
                }
            }
        },
        requestReview: {},
        purchase: { _ in .mockSubscription },
        restorePurchases: { [] },
        getLatestTransaction: { .mockSubscription },
        isEligibleForIntroOffer: { _ in false },
        currentSubscriptionStatus: { groupID in
            [.init(state: .subscribed, productID: "com.example.product.weekly", groupID: groupID)]
        },
        observeSubscriptionStatus: { groupID in
            AsyncStream { continuation in
                continuation.yield([
                    .init(state: .subscribed, productID: "com.example.product.weekly", groupID: groupID)
                ])
                continuation.finish()
            }
        }
    )
}

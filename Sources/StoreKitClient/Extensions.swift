//
//  Extensions.swift
//  StoreKitClient
//
//  Created by Thanh Hai Khong on 27/3/25.
//

import StoreKit

// MARK: - StoreKitClient.Product

extension StoreKitClient.Product {
    public init(rawValue: StoreKit.Product) {
        self.id = rawValue.id
        self.displayName = rawValue.displayName
        self.description = rawValue.description
        self.price = rawValue.price
        self.displayPrice = rawValue.displayPrice
        self.priceFormatStyle = rawValue.priceFormatStyle
        self.type = rawValue.type
        self.subscription = rawValue.subscription.map { sub in
            StoreKitClient.SubscriptionInfo(
                subscriptionPeriod: StoreKitClient.SubscriptionPeriod(rawValue: sub.subscriptionPeriod),
                introductoryOffer: sub.introductoryOffer.map { StoreKitClient.SubscriptionOffer(rawValue: $0) },
                subscriptionGroupID: sub.subscriptionGroupID
            )
        }
    }
}

// MARK: - StoreKitClient.SubscriptionPeriod mapping

extension StoreKitClient.SubscriptionPeriod {
    public init(rawValue: StoreKit.Product.SubscriptionPeriod) {
        self.value = rawValue.value
        switch rawValue.unit {
            case .day: self.unit = .day
            case .week: self.unit = .week
            case .month: self.unit = .month
            case .year: self.unit = .year
            @unknown default: self.unit = .month
        }
    }
}

// MARK: - StoreKitClient.SubscriptionOffer mapping

extension StoreKitClient.SubscriptionOffer {
    public init(rawValue: StoreKit.Product.SubscriptionOffer) {
        self.period = StoreKitClient.SubscriptionPeriod(rawValue: rawValue.period)
        self.periodCount = rawValue.periodCount
        self.price = rawValue.price
        self.displayPrice = rawValue.displayPrice

        switch rawValue.type {
            case .introductory: self.type = .introductory
            case .promotional: self.type = .promotional
            default: self.type = .introductory
        }

        switch rawValue.paymentMode {
            case .freeTrial: self.paymentMode = .freeTrial
            case .payUpFront: self.paymentMode = .payUpFront
            case .payAsYouGo: self.paymentMode = .payAsYouGo
            default: self.paymentMode = .freeTrial
        }
    }
}

// MARK: - StoreKitClient.SubscriptionStatus mapping

@available(iOS 15.0, *)
extension StoreKitClient.SubscriptionStatus {
    /// Maps a StoreKit subscription status into the wrapper value type.
    ///
    /// - Parameters:
    ///   - rawValue: The `Product.SubscriptionInfo.Status` from StoreKit.
    ///   - groupID: The subscription group identifier the status was queried for
    ///     (StoreKit's `Status` does not carry it).
    public init(
        rawValue: StoreKit.Product.SubscriptionInfo.Status,
        groupID: String
    ) {
        self.groupID = groupID

        switch rawValue.state {
            case .subscribed: self.state = .subscribed
            case .expired: self.state = .expired
            case .inBillingRetryPeriod: self.state = .inBillingRetryPeriod
            case .inGracePeriod: self.state = .inGracePeriod
            case .revoked: self.state = .revoked
            default: self.state = .unknown
        }

        if case .verified(let transaction) = rawValue.transaction {
            self.productID = transaction.productID
            self.expirationDate = transaction.expirationDate
        } else {
            self.productID = ""
            self.expirationDate = nil
        }
    }
}

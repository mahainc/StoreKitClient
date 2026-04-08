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
        case .day:   self.unit = .day
        case .week:  self.unit = .week
        case .month: self.unit = .month
        case .year:  self.unit = .year
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
        case .promotional:  self.type = .promotional
        default:            self.type = .introductory
        }

        switch rawValue.paymentMode {
        case .freeTrial:   self.paymentMode = .freeTrial
        case .payUpFront:  self.paymentMode = .payUpFront
        case .payAsYouGo:  self.paymentMode = .payAsYouGo
        default:           self.paymentMode = .freeTrial
        }
    }
}

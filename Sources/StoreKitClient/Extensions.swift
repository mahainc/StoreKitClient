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
        if let period = rawValue.subscription?.subscriptionPeriod {
            self.subscriptionPeriod = StoreKitClient.SubscriptionPeriod(
                unit: period.unit.toClientUnit,
                value: period.value
            )
        }
    }
}

extension StoreKit.Product.SubscriptionPeriod.Unit {
    var toClientUnit: StoreKitClient.SubscriptionPeriod.Unit {
        switch self {
        case .day: return .day
        case .week: return .week
        case .month: return .month
        case .year: return .year
        @unknown default: return .month
        }
    }
}

//
//  Models.swift
//  StoreKitClient
//
//  Created by Thanh Hai Khong on 27/3/25.
//

import Foundation
import CasePaths
import StoreKit

// MARK: - StoreKitClient.Product

extension StoreKitClient {
    /// Represents an in-app purchase product.
    ///
    /// A simplified wrapper around `StoreKit.Product` that contains
    /// essential product information for display and purchase.
    public struct Product: Equatable, Sendable, Hashable {
        /// The unique product identifier from App Store Connect.
        public var id: String

        /// The localized display name of the product.
        public var displayName: String

        /// The localized description of the product.
        public var description: String

        /// The product's price as a decimal value.
        public var price: Decimal

        /// The localized, formatted price string (e.g., "$9.99").
        public var displayPrice: String

        /// Format style carried over from `StoreKit.Product.priceFormatStyle`.
        /// Use this to format any derived `Decimal` (e.g. per-week equivalent
        /// of an annual subscription) so the currency code and locale-specific
        /// separators match `displayPrice` exactly — instead of guessing from
        /// `Locale.current`, which can disagree with the App Store storefront.
        public var priceFormatStyle: Decimal.FormatStyle.Currency

        /// The type of product (consumable, non-consumable, subscription, etc.).
        public var type: StoreKit.Product.ProductType

        /// Subscription info (period, introductory offer). `nil` for non-subscription products.
        public var subscription: SubscriptionInfo?

        public init(
            id: String,
            displayName: String,
            description: String,
            price: Decimal,
            displayPrice: String,
            priceFormatStyle: Decimal.FormatStyle.Currency = .init(code: "USD"),
            type: StoreKit.Product.ProductType,
            subscription: SubscriptionInfo? = nil
        ) {
            self.id = id
            self.displayName = displayName
            self.description = description
            self.price = price
            self.displayPrice = displayPrice
            self.priceFormatStyle = priceFormatStyle
            self.type = type
            self.subscription = subscription
        }
    }
}

// MARK: - StoreKitClient.SubscriptionInfo

extension StoreKitClient {
    /// Subscription-specific information for a product.
    public struct SubscriptionInfo: Equatable, Sendable, Hashable {
        /// The subscription's renewal period.
        public var subscriptionPeriod: SubscriptionPeriod

        /// The introductory offer, if available.
        public var introductoryOffer: SubscriptionOffer?

        /// The subscription group identifier.
        public var subscriptionGroupID: String

        public init(
            subscriptionPeriod: SubscriptionPeriod,
            introductoryOffer: SubscriptionOffer? = nil,
            subscriptionGroupID: String
        ) {
            self.subscriptionPeriod = subscriptionPeriod
            self.introductoryOffer = introductoryOffer
            self.subscriptionGroupID = subscriptionGroupID
        }
    }
}

// MARK: - StoreKitClient.SubscriptionPeriod

extension StoreKitClient {
    /// Represents a subscription's billing period.
    public struct SubscriptionPeriod: Equatable, Sendable, Hashable {
        /// The unit of time for the period.
        public var unit: Unit

        /// The number of units per period (e.g., 1 week, 3 days).
        public var value: Int

        public init(unit: Unit, value: Int) {
            self.unit = unit
            self.value = value
        }

        public enum Unit: String, Sendable, Hashable {
            case day, week, month, year
        }

        /// Human-readable period description (e.g., "1 week", "3 days").
        public var displayDescription: String {
            switch (unit, value) {
            case (.day, 1): return "1 day"
            case (.day, let v): return "\(v) days"
            case (.week, 1): return "1 week"
            case (.week, let v): return "\(v) weeks"
            case (.month, 1): return "1 month"
            case (.month, let v): return "\(v) months"
            case (.year, 1): return "1 year"
            case (.year, let v): return "\(v) years"
            }
        }

        /// Approximate duration in days using fixed conversions (week=7, month=30, year=365).
        ///
        /// Useful for displaying free-trial length when the unit isn't already days.
        /// For calendar-accurate duration, compute from a reference date instead.
        public var approximateDays: Int {
            switch unit {
            case .day:   return value
            case .week:  return value * 7
            case .month: return value * 30
            case .year:  return value * 365
            }
        }
    }
}

// MARK: - StoreKitClient.SubscriptionOffer

extension StoreKitClient {
    /// Represents a subscription offer (introductory or promotional).
    public struct SubscriptionOffer: Equatable, Sendable, Hashable {
        /// The type of offer.
        public var type: OfferType

        /// The unit period of the offer (e.g., `P3D` = 3 days).
        ///
        /// This is one repeat of the offer, not its total length.
        /// Use ``totalPeriod`` for the full duration.
        public var period: SubscriptionPeriod

        /// How many times the unit ``period`` repeats.
        ///
        /// For example, a 6-day free trial may be expressed as
        /// `period = P3D, periodCount = 2`.
        public var periodCount: Int

        /// The offer price (0 for free trials).
        public var price: Decimal

        /// The localized display price.
        public var displayPrice: String

        /// How the customer pays during the offer.
        public var paymentMode: PaymentMode

        public init(
            type: OfferType,
            period: SubscriptionPeriod,
            periodCount: Int,
            price: Decimal,
            displayPrice: String,
            paymentMode: PaymentMode
        ) {
            self.type = type
            self.period = period
            self.periodCount = periodCount
            self.price = price
            self.displayPrice = displayPrice
            self.paymentMode = paymentMode
        }

        public enum OfferType: String, Sendable, Hashable {
            case introductory
            case promotional
        }

        public enum PaymentMode: String, Sendable, Hashable {
            /// Free for the duration (e.g., 3-day free trial).
            case freeTrial
            /// Discounted price upfront for the duration.
            case payUpFront
            /// Discounted price per period for the duration.
            case payAsYouGo
        }

        /// Whether this is a free trial offer.
        public var isFreeTrial: Bool {
            paymentMode == .freeTrial
        }

        /// The total offer duration (`period` × `periodCount`).
        ///
        /// StoreKit splits an offer into a unit period and a repeat count
        /// (e.g., `P3D × 2` = 6 days). Use this to get the combined span.
        public var totalPeriod: SubscriptionPeriod {
            SubscriptionPeriod(unit: period.unit, value: period.value * periodCount)
        }

        /// Human-readable offer description (e.g., "3 days free trial").
        public var displayDescription: String {
            switch paymentMode {
            case .freeTrial:
                return "\(totalPeriod.displayDescription) free trial"
            case .payUpFront:
                return "\(displayPrice) for \(totalPeriod.displayDescription)"
            case .payAsYouGo:
                return "\(displayPrice)/\(period.unit.rawValue) for \(periodCount) \(period.unit.rawValue)\(periodCount > 1 ? "s" : "")"
            }
        }
    }
}

// MARK: - StoreKitClient.TransactionEnvironment

extension StoreKitClient {
    /// The environment in which a transaction was made.
    public enum TransactionEnvironment: String, Sendable, Equatable {
        case sandbox
        case production
        case xcode
        case unknown
    }
}

// MARK: - StoreKitClient.Transaction

extension StoreKitClient {
    /// Represents a verified StoreKit transaction.
    ///
    /// A wrapper around `StoreKit.Transaction` that provides convenient access
    /// to transaction details and pricing information.
    public struct Transaction: Equatable, Sendable {
        /// The underlying StoreKit transaction, if available.
        ///
        /// This will be `nil` for mock transactions used in testing and previews.
        public let rawValue: StoreKit.Transaction?

        /// The unique identifier for this transaction.
        public var id: UInt64 { rawValue?.id ?? 0 }

        /// The identifier of the product that was purchased.
        public var productID: String { rawValue?.productID ?? "" }

        /// The type of product that was purchased.
        public var productType: StoreKit.Product.ProductType { rawValue?.productType ?? .nonConsumable }

        /// The date when the purchase was made.
        public var purchaseDate: Date? { rawValue?.purchaseDate }

        /// The date when the subscription expires (for subscriptions only).
        public var expirationDate: Date? { rawValue?.expirationDate }

        /// The quantity of items purchased (for consumables).
        public var purchasedQuantity: Int { rawValue?.purchasedQuantity ?? 1 }

        /// The type of offer that was applied to this transaction, if any.
        public var offerType: StoreKit.Transaction.OfferType? { rawValue?.offerType }

        /// The identifier of the offer that was applied, if any.
        public var offerID: String? { rawValue?.offerID }

        /// Whether this transaction was purchased with a free trial.
        public var isFreeTrial: Bool { offerType == .introductory }

        /// The environment in which this transaction was made.
        public var environment: TransactionEnvironment {
            guard let rawValue else { return .unknown }
            if #available(iOS 16.0, macOS 13.0, *) {
                return switch rawValue.environment {
                case .sandbox: .sandbox
                case .production: .production
                case .xcode: .xcode
                default: .unknown
                }
            } else {
                return .unknown
            }
        }

        /// The localized, formatted price string for this transaction.
        ///
        /// Returns "Unknown Price" if the transaction has no pricing information.
        public var displayPrice: String? {
            guard let rawValue else { return "Unknown Price" }

            let formatter = NumberFormatter()
            formatter.numberStyle = .currency

            if #available(iOS 16.0, macOS 13.0, *) {
                guard let price = rawValue.price else {
                    return "Unknown Price"
                }
                if let currency = rawValue.currency {
                    formatter.currencyCode = currency.identifier
                    return formatter.string(from: price as NSDecimalNumber) ?? "\(price) \(currency.identifier)"
                }
                return formatter.string(from: price as NSDecimalNumber) ?? "\(price)"
            } else {
                guard let price = rawValue.price, let currencyCode = rawValue.currencyCode else {
                    return "Unknown Price"
                }
                formatter.currencyCode = currencyCode
                return formatter.string(from: price as NSDecimalNumber) ?? "\(price) \(currencyCode)"
            }
        }

        public init(rawValue: StoreKit.Transaction? = nil) {
            self.rawValue = rawValue
        }

        /// Checks if the transaction has expired.
        ///
        /// - Returns: `true` if the transaction has an expiration date in the past, `false` otherwise.
        public var isExpired: Bool {
            guard let expirationDate else { return false }
            return expirationDate < Date()
        }

        /// Mock consumable transaction for testing
        public static let mockConsumable = Transaction(rawValue: nil)

        /// Mock active subscription transaction for testing
        public static let mockSubscription = Transaction(rawValue: nil)

        /// Mock expired subscription transaction for testing
        public static let mockExpiredSubscription = Transaction(rawValue: nil)
    }
}

// MARK: - StoreKitClient.TransactionEvent

extension StoreKitClient {
    /// Events emitted by the transaction observation stream.
    @CasePathable
    public enum TransactionEvent: Sendable {
        /// A transaction was updated or newly created.
        case updated(StoreKitClient.Transaction)

        /// A transaction was removed or revoked.
        case removed(StoreKitClient.Transaction)

        /// Transaction verification failed.
		case verificationFailed(Swift.Error)
    }
}

// MARK: - StoreKitClient.StoreClientError

extension StoreKitClient {
    /// Errors that can occur during StoreKit operations.
	public enum `Error`: Swift.Error, Sendable, LocalizedError {
        /// Failed to fetch products from the App Store.
        ///
        /// - Parameters:
        ///   - productIDs: The product identifiers that were requested.
        ///   - underlyingError: The error returned by StoreKit.
		case fetchProductsFailed(productIDs: Set<String>, underlyingError: Swift.Error)

        /// The transaction failed verification.
        ///
        /// - Parameter error: The verification error.
		case unverifiedTransaction(Swift.Error)

        /// The user cancelled the purchase.
        case userCancelled

        /// The purchase is pending approval (e.g., parental approval required).
        case purchasePending

        /// The purchase result is unknown or unexpected.
        case unknownPurchaseResult

        /// The requested product was not found.
        ///
        /// - Parameter productID: The identifier of the product that was not found.
        case productNotFound(productID: String)

        public var errorDescription: String? {
            switch self {
            case .fetchProductsFailed(let productIDs, let underlyingError):
                return "Failed to fetch products \(productIDs.joined(separator: ", ")): \(underlyingError.localizedDescription)"
            case .unverifiedTransaction(let error):
                return "Transaction verification failed: \(error.localizedDescription)"
            case .userCancelled:
                return "Purchase was cancelled by the user"
            case .purchasePending:
                return "Purchase is pending approval"
            case .unknownPurchaseResult:
                return "Purchase completed with an unknown result"
            case .productNotFound(let productID):
                return "Product '\(productID)' was not found in the App Store"
            }
        }

        public var recoverySuggestion: String? {
            switch self {
            case .fetchProductsFailed:
                return "Check your network connection and ensure the product IDs are registered in App Store Connect."
            case .unverifiedTransaction:
                return "The transaction could not be verified. Please try again."
            case .userCancelled:
                return nil
            case .purchasePending:
                return "The purchase requires parental approval. Please check back later."
            case .unknownPurchaseResult:
                return "Please contact support if you were charged but did not receive your purchase."
            case .productNotFound:
                return "Ensure the product ID is correct and registered in App Store Connect."
            }
        }
    }
}

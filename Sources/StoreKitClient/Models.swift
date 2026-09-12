//
//  Models.swift
//  StoreKitClient
//
//  Created by Thanh Hai Khong on 27/3/25.
//

import CasePaths
import Foundation
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

        public init(
            unit: Unit,
            value: Int
        ) {
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
                case .day: return value
                case .week: return value * 7
                case .month: return value * 30
                case .year: return value * 365
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
                    return
                        "\(displayPrice)/\(period.unit.rawValue) for \(periodCount) \(period.unit.rawValue)\(periodCount > 1 ? "s" : "")"
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
    ///
    /// A transaction built from StoreKit reads every field off ``rawValue``. One built for a
    /// mock, a preview, or a fixture has no `rawValue` and reports the field values it was
    /// handed instead — without them a `nil`-backed transaction answers `0` for ``id`` and
    /// `""` for ``productID``, which makes two of them indistinguishable and leaves any flow
    /// keyed on the product or the transaction identifier untestable.
    public struct Transaction: Equatable, Sendable {
        /// The underlying StoreKit transaction, if available.
        ///
        /// This will be `nil` for mock transactions used in testing and previews.
        public let rawValue: StoreKit.Transaction?

        /// The field values reported when no StoreKit transaction backs this one.
        ///
        /// Read only where `rawValue` reports nothing, so a real transaction is never masked.
        private let overrides: Overrides

        /// The unique identifier for this transaction.
        public var id: UInt64 { rawValue?.id ?? overrides.id ?? 0 }

        /// The identifier of the first transaction in this purchase's chain.
        ///
        /// Every renewal of a subscription repeats the original's identifier, so this — not
        /// ``id`` — is what a backend keys a subscriber on. It equals ``id`` for a first
        /// purchase, and is `nil` only for a fixture that was not given one.
        public var originalID: UInt64? { rawValue?.originalID ?? overrides.originalID }

        /// The identifier of the product that was purchased.
        public var productID: String { rawValue?.productID ?? overrides.productID ?? "" }

        /// The type of product that was purchased.
        public var productType: StoreKit.Product.ProductType {
            rawValue?.productType ?? overrides.productType ?? .nonConsumable
        }

        /// The date when the purchase was made.
        public var purchaseDate: Date? { rawValue?.purchaseDate ?? overrides.purchaseDate }

        /// The date when the subscription expires (for subscriptions only).
        public var expirationDate: Date? { rawValue?.expirationDate ?? overrides.expirationDate }

        /// The quantity of items purchased (for consumables).
        public var purchasedQuantity: Int { rawValue?.purchasedQuantity ?? overrides.purchasedQuantity ?? 1 }

        /// The type of offer that was applied to this transaction, if any.
        public var offerType: StoreKit.Transaction.OfferType? { rawValue?.offerType ?? overrides.offerType }

        /// The identifier of the offer that was applied, if any.
        public var offerID: String? { rawValue?.offerID ?? overrides.offerID }

        /// Whether this transaction was purchased with a free trial.
        public var isFreeTrial: Bool { offerType == .introductory }

        /// The amount charged, in the currency ``currency`` names.
        ///
        /// `nil` when StoreKit recorded no price, as it does for transactions restored from
        /// older receipts.
        public var price: Decimal? { rawValue?.price ?? overrides.price }

        /// The ISO 4217 code of the currency ``price`` is denominated in (e.g. `"USD"`).
        public var currency: String? {
            guard let rawValue else { return overrides.currency }
            return rawValue.currency?.identifier ?? overrides.currency
        }

        /// The App Store storefront the purchase was made in, as an ISO 3166-1 alpha-3 country
        /// code (e.g. `"USA"`).
        ///
        /// The storefront decides price and tax, and is not necessarily the device's locale.
        /// `nil` below iOS 17 / macOS 14, where StoreKit does not report it on a transaction.
        public var salesRegion: String? {
            guard let rawValue else { return overrides.salesRegion }
            return rawValue.storefront.countryCode
        }

        /// Whether this account bought the product or received it through Family Sharing.
        public var ownershipType: StoreKit.Transaction.OwnershipType? {
            rawValue?.ownershipType ?? overrides.ownershipType
        }

        /// The environment in which this transaction was made.
        public var environment: TransactionEnvironment {
            guard let rawValue else { return overrides.environment ?? .unknown }
            return switch rawValue.environment {
                case .sandbox: .sandbox
                case .production: .production
                case .xcode: .xcode
                default: .unknown
            }
        }

        /// The localized, formatted price string for this transaction.
        ///
        /// Returns "Unknown Price" if the transaction has no pricing information.
        public var displayPrice: String? {
            guard let price else { return "Unknown Price" }

            let formatter = NumberFormatter()
            formatter.numberStyle = .currency

            guard let currency else {
                return formatter.string(from: price as NSDecimalNumber) ?? "\(price)"
            }

            formatter.currencyCode = currency
            return formatter.string(from: price as NSDecimalNumber) ?? "\(price) \(currency)"
        }

        /// Checks if the transaction has expired.
        ///
        /// - Returns: `true` if the transaction has an expiration date in the past, `false` otherwise.
        public var isExpired: Bool {
            guard let expirationDate else { return false }
            return expirationDate < Date()
        }

        public init(rawValue: StoreKit.Transaction? = nil) {
            self.rawValue = rawValue
            self.overrides = Overrides()
        }

        /// Builds a transaction that carries its own field values, with no StoreKit behind it.
        ///
        /// Everything but the identity of the purchase is optional: supply the fields the code
        /// under test actually reads and leave the rest at the defaults a `nil`-backed
        /// transaction has always reported.
        ///
        /// - Parameters:
        ///   - id: The transaction identifier.
        ///   - productID: The product that was bought.
        ///   - productType: What kind of product it was.
        ///   - originalID: The first transaction in this purchase's chain. Defaults to `id`.
        public init(
            id: UInt64,
            productID: String,
            productType: StoreKit.Product.ProductType,
            originalID: UInt64? = nil,
            purchaseDate: Date? = nil,
            expirationDate: Date? = nil,
            purchasedQuantity: Int? = nil,
            offerType: StoreKit.Transaction.OfferType? = nil,
            offerID: String? = nil,
            environment: TransactionEnvironment? = nil,
            price: Decimal? = nil,
            currency: String? = nil,
            salesRegion: String? = nil,
            ownershipType: StoreKit.Transaction.OwnershipType? = nil
        ) {
            self.rawValue = nil
            self.overrides = Overrides(
                id: id,
                originalID: originalID,
                productID: productID,
                productType: productType,
                purchaseDate: purchaseDate,
                expirationDate: expirationDate,
                purchasedQuantity: purchasedQuantity,
                offerType: offerType,
                offerID: offerID,
                environment: environment,
                price: price,
                currency: currency,
                salesRegion: salesRegion,
                ownershipType: ownershipType
            )
        }

        /// Mock consumable transaction for testing
        public static let mockConsumable = Transaction(
            id: 2_000_000_001,
            productID: "com.example.coins100",
            productType: .consumable,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            price: 0.99,
            currency: "USD",
            salesRegion: "USA",
            ownershipType: .purchased
        )

        /// Mock active subscription transaction for testing
        public static let mockSubscription = Transaction(
            id: 2_000_000_002,
            productID: "com.example.product.weekly",
            productType: .autoRenewable,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            expirationDate: Date(timeIntervalSinceNow: 7 * 24 * 60 * 60),
            price: 0.99,
            currency: "USD",
            salesRegion: "USA",
            ownershipType: .purchased
        )

        /// Mock expired subscription transaction for testing
        public static let mockExpiredSubscription = Transaction(
            id: 2_000_000_003,
            productID: "com.example.product.weekly",
            productType: .autoRenewable,
            purchaseDate: Date(timeIntervalSince1970: 1_600_000_000),
            expirationDate: Date(timeIntervalSince1970: 1_600_604_800),
            price: 0.99,
            currency: "USD",
            salesRegion: "USA",
            ownershipType: .purchased
        )
    }
}

// MARK: - StoreKitClient.Transaction.Overrides

extension StoreKitClient.Transaction {
    /// The field values a transaction with no `rawValue` reports.
    ///
    /// Every field is optional so that an unset one falls through to the same default a
    /// `nil`-backed transaction has always answered with.
    struct Overrides: Equatable, Sendable {
        var id: UInt64?
        var originalID: UInt64?
        var productID: String?
        var productType: StoreKit.Product.ProductType?
        var purchaseDate: Date?
        var expirationDate: Date?
        var purchasedQuantity: Int?
        var offerType: StoreKit.Transaction.OfferType?
        var offerID: String?
        var environment: StoreKitClient.TransactionEnvironment?
        var price: Decimal?
        var currency: String?
        var salesRegion: String?
        var ownershipType: StoreKit.Transaction.OwnershipType?
    }
}

// MARK: - StoreKitClient.SubscriptionStatus

extension StoreKitClient {
    /// A snapshot of a subscription's renewal status within a subscription group.
    ///
    /// Mapped from `StoreKit.Product.SubscriptionInfo.Status`, this is the canonical
    /// signal for whether a subscription (or free trial) is still active. Unlike a raw
    /// transaction, it reflects natural expiration: when a trial lapses without renewal,
    /// the state becomes ``RenewalState/expired`` and ``isActive`` becomes `false`.
    public struct SubscriptionStatus: Equatable, Sendable, Hashable {
        /// The renewal state reported by StoreKit.
        public var state: RenewalState

        /// The product identifier of the transaction backing this status.
        public var productID: String

        /// The subscription group identifier this status belongs to.
        public var groupID: String

        /// The expiration date of the backing transaction, if any.
        public var expirationDate: Date?

        public init(
            state: RenewalState,
            productID: String,
            groupID: String,
            expirationDate: Date? = nil
        ) {
            self.state = state
            self.productID = productID
            self.groupID = groupID
            self.expirationDate = expirationDate
        }

        /// Whether this subscription currently grants entitlement.
        ///
        /// `true` for ``RenewalState/subscribed``, ``RenewalState/inGracePeriod``, and
        /// ``RenewalState/inBillingRetryPeriod`` (Apple still grants access during grace and
        /// billing-retry). `false` for ``RenewalState/expired``, ``RenewalState/revoked``,
        /// and ``RenewalState/unknown``.
        public var isActive: Bool {
            switch state {
                case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
                    return true
                case .expired, .revoked, .unknown:
                    return false
            }
        }

        /// The renewal state of a subscription, mirroring `Product.SubscriptionInfo.RenewalState`.
        public enum RenewalState: String, Sendable, Hashable {
            /// The subscription is active and will renew.
            case subscribed
            /// The subscription expired and did not renew (e.g. a free trial that lapsed).
            case expired
            /// Renewal failed and StoreKit is retrying billing; access is still granted.
            case inBillingRetryPeriod
            /// The subscription is in its grace period after a billing issue; access is still granted.
            case inGracePeriod
            /// The subscription was revoked (e.g. refund or family-sharing removal).
            case revoked
            /// The state could not be determined.
            case unknown
        }
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

        /// A purchase entry point was called for the wrong kind of product.
        ///
        /// The three purchase methods are not interchangeable — only a consumable may defer
        /// `finish()` behind a server verify — so each one checks the product's real type
        /// rather than trusting the call site.
        ///
        /// - Parameters:
        ///   - productID: The product that was asked for.
        ///   - expected: The type the entry point serves.
        ///   - actual: The type the App Store actually reports.
        case productTypeMismatch(
            productID: String,
            expected: StoreKit.Product.ProductType,
            actual: StoreKit.Product.ProductType
        )

        public var errorDescription: String? {
            switch self {
                case .fetchProductsFailed(let productIDs, let underlyingError):
                    return
                        "Failed to fetch products \(productIDs.joined(separator: ", ")): \(underlyingError.localizedDescription)"
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
                case .productTypeMismatch(let productID, let expected, let actual):
                    return "Product '\(productID)' is \(actual), not \(expected)"
            }
        }

        public var recoverySuggestion: String? {
            switch self {
                case .fetchProductsFailed:
                    return
                        "Check your network connection and ensure the product IDs are registered in App Store Connect."
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
                case .productTypeMismatch:
                    return
                        "Use subscribe(_:) for subscriptions, purchase(_:) for non-consumables, and purchaseConsumable(...) for consumables."
            }
        }
    }
}

extension StoreKitClient {
    /// What the FunnelClient StoreKit port needs that its methods do not carry.
    public struct FunnelSettings: Sendable {
        /// Fallback set for `restore(productIDs:)`: when the caller's requested IDs match
        /// nothing, any entitlement in this set still counts as restored.
        public let premiumProductIDs: Set<String>

        /// Ties a credit purchase to the buyer in App Store Server notifications. `nil` uses
        /// the vendor identifier; supply your own where `UIKit` is absent or the backend keys
        /// on something else.
        public let appAccountToken: (@Sendable () -> UUID?)?

        public init(
            premiumProductIDs: Set<String> = [],
            appAccountToken: (@Sendable () -> UUID?)? = nil
        ) {
            self.premiumProductIDs = premiumProductIDs
            self.appAccountToken = appAccountToken
        }
    }
}

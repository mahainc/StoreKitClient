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

        /// The type of product (consumable, non-consumable, subscription, etc.).
        public var type: StoreKit.Product.ProductType

        /// The subscription period for auto-renewable subscriptions.
        public var subscriptionPeriod: SubscriptionPeriod?

        public init(
            id: String,
            displayName: String,
            description: String,
            price: Decimal,
            displayPrice: String,
            type: StoreKit.Product.ProductType,
            subscriptionPeriod: SubscriptionPeriod? = nil
        ) {
            self.id = id
            self.displayName = displayName
            self.description = description
            self.price = price
            self.displayPrice = displayPrice
            self.type = type
            self.subscriptionPeriod = subscriptionPeriod
        }
    }

    /// Represents the duration of a subscription period.
    public struct SubscriptionPeriod: Equatable, Sendable, Hashable {
        public var unit: Unit
        public var value: Int

        public enum Unit: Sendable, Equatable, Hashable {
            case day, week, month, year
        }

        public init(unit: Unit, value: Int) {
            self.unit = unit
            self.value = value
        }
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

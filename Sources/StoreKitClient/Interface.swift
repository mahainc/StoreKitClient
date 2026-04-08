//
//  StoreKitClient Interface
//  A dependency-injectable wrapper for Apple's StoreKit framework
//

import DependenciesMacros
import StoreKit

/// A dependency client for interacting with Apple's StoreKit framework.
///
/// `StoreKitClient` provides a testable, injectable interface for in-app purchases,
/// subscriptions, and transaction management. It supports dependency injection through
/// the Composable Architecture's dependency system.
///
/// ## Usage
///
/// ```swift
/// @Dependency(\.storeKitClient) var storeKitClient
///
/// // Load products
/// let products = try await storeKitClient.loadProducts(["com.example.product"])
///
/// // Make a purchase
/// let transaction = try await storeKitClient.purchase("com.example.product")
/// ```
///
/// ## Testing
///
/// Use the provided mock implementations for testing:
/// - `.happy` - Successful scenarios with mock products
/// - `.failing` - Error scenarios for failure testing
/// - `.noop` - Silent no-op implementation
@DependencyClient
@available(iOS 15.0, *)
public struct StoreKitClient: Sendable {

    /// Returns the URL for the app's receipt, if available.
    ///
    /// - Returns: The receipt URL, or `nil` if unavailable.
    public var receiptURL: @Sendable () -> URL?

    /// Checks whether the user is allowed to make payments.
    ///
    /// - Returns: `true` if the user can make payments, `false` otherwise.
    public var canMakePayments: @Sendable () -> Bool = { false }

    /// Loads products from the App Store for the specified product identifiers.
    ///
    /// Products are cached to minimize redundant StoreKit API calls.
    ///
    /// - Parameter productIDs: A set of product identifier strings registered in App Store Connect.
    /// - Returns: An array of available products matching the provided identifiers.
    /// - Throws: `StoreClientError.fetchProductsFailed` if products cannot be loaded.
    public var loadProducts: @Sendable (_ productIDs: Set<String>) async throws -> [StoreKitClient.Product]

    /// Processes unfinished consumable transactions.
    ///
    /// Use this on app launch to deliver consumables that were purchased but not yet delivered.
    /// The handler is called for each unfinished consumable, and you should deliver the content
    /// before the handler completes.
    ///
    /// - Parameter deliverConsumable: A closure called for each unfinished consumable transaction.
    ///   Throw an error if delivery fails to prevent marking the transaction as delivered.
    public var processUnfinishedConsumables: @Sendable (_ deliverConsumable: @Sendable @escaping (StoreKitClient.Transaction) async throws -> Void) async -> Void

    /// Observes transaction updates in real-time.
    ///
    /// Subscribe to this stream to receive notifications about new transactions,
    /// transaction updates, and verification failures.
    ///
    /// - Returns: An `AsyncStream` that emits `TransactionEvent` values.
    public var observeTransactions: @Sendable () async -> AsyncStream<TransactionEvent> = { .finished }

    /// Requests an App Store review from the user.
    ///
    /// This follows Apple's guidelines for review requests and will only show the prompt
    /// when appropriate. On platforms without UI support (e.g., watchOS, macOS), this
    /// logs a message instead.
    ///
    /// - Note: The system controls the frequency of review prompts.
    public var requestReview: @Sendable () async -> Void

    /// Initiates a purchase for the specified product.
    ///
    /// This method handles the complete purchase flow including verification
    /// of the transaction.
    ///
    /// - Parameter productID: The identifier of the product to purchase.
    /// - Returns: A verified transaction for the purchase.
    /// - Throws:
    ///   - `StoreClientError.productNotFound` if the product doesn't exist
    ///   - `StoreClientError.userCancelled` if the user cancels the purchase
    ///   - `StoreClientError.purchasePending` if the purchase requires parental approval
    ///   - `StoreClientError.unverifiedTransaction` if verification fails
    public var purchase: @Sendable (_ productID: String) async throws -> StoreKitClient.Transaction

    /// Restores previously purchased products.
    ///
    /// This queries the user's current entitlements and returns all verified transactions.
    ///
    /// - Returns: An array of verified transactions for the user's current entitlements.
    public var restorePurchases: @Sendable () async -> [StoreKitClient.Transaction] = { [] }

    /// Retrieves the latest transaction with the most recent expiration date.
    ///
    /// Useful for subscription management to find the user's active or most recent subscription.
    ///
    /// - Returns: The transaction with the latest expiration date, or `nil` if no transactions exist.
    public var getLatestTransaction: @Sendable () async -> StoreKitClient.Transaction?

    /// Checks whether the user is eligible for an introductory offer in the given subscription group.
    ///
    /// Use this to determine whether to show "Free Trial" messaging on your paywall.
    /// A user is eligible only if they've never had a subscription in the group.
    ///
    /// - Parameter groupID: The subscription group identifier from App Store Connect.
    /// - Returns: `true` if the user is eligible for the introductory offer.
    public var isEligibleForIntroOffer: @Sendable (_ groupID: String) async -> Bool = { _ in false }
}

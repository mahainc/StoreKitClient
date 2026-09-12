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
    public var processUnfinishedConsumables:
        @Sendable (_ deliverConsumable: @Sendable @escaping (StoreKitClient.Transaction) async throws -> Void) async ->
            Void

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

    /// Buys a non-consumable — a permanent, one-time unlock such as "remove ads".
    ///
    /// This method handles the complete purchase flow including verification
    /// of the transaction, and finishes it before returning: the App Store owns the
    /// entitlement from here on, so there is nothing left to deliver.
    ///
    /// A permanent unlock is not a subscription and not a credit pack — use ``subscribe``
    /// or ``purchaseConsumable`` for those. StoreKit's own product type decides, so handing
    /// this the wrong kind of product throws rather than charging for the wrong thing.
    ///
    /// - Parameter productID: A non-consumable product. Any other type throws `productTypeMismatch`.
    /// - Returns: A verified transaction for the purchase.
    /// - Throws:
    ///   - `StoreClientError.productNotFound` if the product doesn't exist
    ///   - `StoreClientError.productTypeMismatch` if the product is not a non-consumable
    ///   - `StoreClientError.userCancelled` if the user cancels the purchase
    ///   - `StoreClientError.purchasePending` if the purchase requires parental approval
    ///   - `StoreClientError.unverifiedTransaction` if verification fails
    public var purchase: @Sendable (_ productID: String) async throws -> StoreKitClient.Transaction

    /// Buys a subscription — auto-renewable or non-renewing — and finishes it before returning.
    ///
    /// Nothing is deferred, because the App Store, not a server of yours, decides whether the
    /// subscription still entitles the user; read that back with ``currentSubscriptionStatus``
    /// rather than from the transaction this returns.
    ///
    /// - Parameter productID: An auto-renewable or non-renewing product. Any other type throws
    ///   `productTypeMismatch`.
    /// - Returns: A verified transaction for the purchase.
    /// - Throws:
    ///   - `StoreClientError.productNotFound` if the product doesn't exist
    ///   - `StoreClientError.productTypeMismatch` if the product is not a subscription
    ///   - `StoreClientError.userCancelled` if the user cancels the purchase
    ///   - `StoreClientError.purchasePending` if the purchase requires parental approval
    ///   - `StoreClientError.unverifiedTransaction` if verification fails
    public var subscribe: @Sendable (_ productID: String) async throws -> StoreKitClient.Transaction

    /// Buys a consumable, holding the transaction open until `verify` succeeds.
    ///
    /// Use this for anything whose value is granted by a server — credit packs, coin bundles.
    /// `finish()` is what stops StoreKit re-delivering a transaction, so it is called only
    /// after `verify` returns. If `verify` throws, the transaction is left **unfinished** on
    /// purpose and StoreKit hands it back on a later launch, where `redeliveryListener(verify:)`
    /// retries it — a transient backend failure must not cost the user a paid grant.
    ///
    /// - Parameters:
    ///   - productID: A consumable product. Any other type throws `productTypeMismatch`.
    ///   - appAccountToken: Ties the purchase to your own account identity in App Store Server
    ///     notifications. Pass `nil` if the backend does not need it.
    ///   - verify: Records the grant. Throwing keeps the transaction alive for a retry.
    public var purchaseConsumable:
        @Sendable (
            _ productID: String,
            _ appAccountToken: UUID?,
            _ verify: @Sendable @escaping (StoreKitClient.Transaction) async throws -> Void
        ) async throws -> StoreKitClient.Transaction

    /// Starts a long-lived listener that re-verifies consumables StoreKit re-delivers.
    ///
    /// Covers the purchase that was paid for but never granted, because the app died between
    /// the purchase and the verifier's reply. Same contract as `purchaseConsumable`: a failed
    /// verify leaves the transaction unfinished so it returns again.
    ///
    /// - Returns: The listener task. Cancel it to stop listening; it never finishes on its own.
    public var redeliveryListener:
        @Sendable (_ verify: @Sendable @escaping (StoreKitClient.Transaction) async throws -> Void) -> Task<
            Void, Never
        > = { _ in Task {} }

    /// Asks the App Store to refresh this device's transaction records.
    ///
    /// Call it before ``restorePurchases`` on an explicit "Restore Purchases" tap and nowhere
    /// else: it can present a sign-in prompt, which is hostile on launch. It is separate from
    /// ``restorePurchases`` so that a refusal to sign in — or a network failure — surfaces as a
    /// thrown error rather than as an empty list that reads like "you never bought anything".
    ///
    /// - Throws: Whatever StoreKit reports, typically a cancelled or failed authentication.
    public var syncAppStore: @Sendable () async throws -> Void = {}

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

    /// Returns the current subscription status for every subscription in the given group.
    ///
    /// This is the canonical, expiration-aware way to know whether a subscription (or free
    /// trial) is still active. Unlike ``getLatestTransaction`` — which returns a raw
    /// transaction regardless of expiry — each ``StoreKitClient/SubscriptionStatus`` reflects
    /// natural lapse: a trial that ended without renewal reports ``StoreKitClient/SubscriptionStatus/RenewalState/expired``
    /// and ``StoreKitClient/SubscriptionStatus/isActive`` `false`.
    ///
    /// Call this on app launch and on foreground resume to catch expirations that happened
    /// while the app was not running (StoreKit emits no live update for a plain expiry).
    ///
    /// - Parameter groupID: The subscription group identifier from App Store Connect.
    /// - Returns: The status of each subscription in the group. Empty if the user never subscribed.
    public var currentSubscriptionStatus: @Sendable (_ groupID: String) async -> [SubscriptionStatus] = { _ in [] }

    /// Observes subscription-status changes for the given group in real time.
    ///
    /// Emits an initial snapshot immediately, then a fresh status array whenever StoreKit
    /// reports a transaction change (renewal, expiration, revocation, upgrade). Subscribe to
    /// this to downgrade a user the moment their trial or subscription lapses while the app
    /// is running.
    ///
    /// - Parameter groupID: The subscription group identifier from App Store Connect.
    /// - Returns: An `AsyncStream` emitting the group's status whenever it changes.
    public var observeSubscriptionStatus: @Sendable (_ groupID: String) async -> AsyncStream<[SubscriptionStatus]> = {
        _ in .finished
    }

    /// Host-supplied values the FunnelClient StoreKit port needs but does not carry.
    public var funnelSettings: @Sendable () -> FunnelSettings = { FunnelSettings() }
}

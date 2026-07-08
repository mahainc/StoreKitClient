//
//  StoreKitLiveActor.swift
//  StoreKitClient
//
//  Created by Thanh Hai Khong on 31/3/25.
//

import StoreKit
import StoreKitClient

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - UserDefaults Keys

private enum UserDefaultsKey {
    private static let prefix = "StoreKitClient"

    static func deliveredConsumable(_ transactionID: UInt64) -> String {
        "\(prefix)_delivered_\(transactionID)"
    }
}

// MARK: - StoreKitLiveActor

actor StoreKitLiveActor {
    private let userDefaults: UserDefaults
    private let logger: (String) -> Void
    private var productCache: [String: StoreKit.Product] = [:]
    private var transactionUpdateTask: Task<Void, Never>?

    init(
        userDefaults: UserDefaults = .standard,
        logger: @escaping (String) -> Void = { message in
            #if DEBUG
                print("🛍️ [STORE_KIT_LIVE_ACTOR]: \(message)")
            #endif
        }
    ) {
        self.userDefaults = userDefaults
        self.logger = logger

        self.transactionUpdateTask = Task { @Sendable in
            for await update in StoreKit.Transaction.updates {
                switch update {
                    case .verified(let transaction):
                        #if DEBUG
                            print("🛍️ [STORE_KIT_LIVE_ACTOR]: Transaction update received: \(transaction.productID)")
                        #endif
                        // Finish the transaction for non-consumables and non-renewable subscriptions
                        // Consumables will be finished after delivery in processUnfinishedConsumables
                        if transaction.productType != .consumable {
                            await transaction.finish()
                        }
                    case .unverified(_, let error):
                        #if DEBUG
                            print("🛍️ [STORE_KIT_LIVE_ACTOR]: Unverified transaction update: \(error)")
                        #endif
                }
            }
        }
    }

    deinit {
        transactionUpdateTask?.cancel()
    }

    nonisolated func receiptURL() -> URL? {
        Bundle.main.appStoreReceiptURL
    }

    nonisolated func canMakePayments() -> Bool {
        AppStore.canMakePayments
    }

    func loadProducts(for productIDs: Set<String>) async throws -> [StoreKitClient.Product] {
        let uncachedIDs = productIDs.filter { productCache[$0] == nil }
        if !uncachedIDs.isEmpty {
            let fetched = try await fetchStoreKitProducts(for: uncachedIDs)
            for product in fetched {
                productCache[product.id] = product
            }
        }
        return productIDs.compactMap { productCache[$0] }.map(StoreKitClient.Product.init)
    }

    func processUnfinishedConsumables(handler: @Sendable @escaping (StoreKitClient.Transaction) async throws -> Void)
        async
    {
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(from: entitlement) else { continue }
            if transaction.productType == .consumable {
                await deliverConsumable(transaction: transaction, with: handler)
            }
        }
    }

    nonisolated func observeTransactions() async -> AsyncStream<StoreKitClient.TransactionEvent> {
        AsyncStream { continuation in
            let actor = self
            Task(priority: .background) {
                for await update in StoreKit.Transaction.updates {
                    continuation.yield(await actor.handleTransactionUpdate(update))
                }
                continuation.finish()
            }
        }
    }

    func requestReview() async {
        #if canImport(UIKit) && !os(watchOS)
            guard let windowScene = await currentWindowScene() else {
                logger("No window scene found for review request")
                return
            }
            if #available(iOS 16.0, *) {
                await AppStore.requestReview(in: windowScene)
            } else {
                await SKStoreReviewController.requestReview(in: windowScene)
            }
        #else
            logger("Review request not supported on this platform")
        #endif
    }

    func purchase(productID: String) async throws -> StoreKitClient.Transaction {
        let product = try await fetchOrGetCachedProduct(for: productID)
        let purchaseResult = try await product.purchase()
        let (wrapped, raw) = try handlePurchaseResult(purchaseResult)
        await raw.finish()
        return wrapped
    }

    func restorePurchases() async -> [StoreKitClient.Transaction] {
        var restored: [StoreKitClient.Transaction] = []
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard let transaction = verifiedTransaction(from: entitlement) else { continue }
            guard isEntitlementActive(transaction) else { continue }
            let wrapped = StoreKitClient.Transaction(rawValue: transaction)
            restored.append(wrapped)
        }
        logger("Restored \(restored.count) transactions")
        return restored
    }

    func isEligibleForIntroOffer(groupID: String) async -> Bool {
        await StoreKit.Product.SubscriptionInfo.isEligibleForIntroOffer(for: groupID)
    }

    func currentSubscriptionStatus(groupID: String) async -> [StoreKitClient.SubscriptionStatus] {
        do {
            let statuses = try await StoreKit.Product.SubscriptionInfo.status(for: groupID)
            return statuses.map { StoreKitClient.SubscriptionStatus(rawValue: $0, groupID: groupID) }
        } catch {
            logger("Failed to fetch subscription status for \(groupID): \(error)")
            return []
        }
    }

    nonisolated func observeSubscriptionStatus(groupID: String) async -> AsyncStream<
        [StoreKitClient.SubscriptionStatus]
    > {
        AsyncStream { continuation in
            let actor = self
            Task(priority: .background) {
                // Initial snapshot so a cold subscriber immediately learns the current state.
                continuation.yield(await actor.currentSubscriptionStatus(groupID: groupID))
                // StoreKit refreshes the status cache before yielding each transaction update,
                // so re-querying on every tick reflects renewals, expirations, and revocations.
                for await _ in StoreKit.Transaction.updates {
                    continuation.yield(await actor.currentSubscriptionStatus(groupID: groupID))
                }
                continuation.finish()
            }
        }
    }

    func getLatestTransaction() async -> StoreKitClient.Transaction? {
        var latestTransaction: Transaction?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            guard isEntitlementActive(transaction) else { continue }

            let currentExpiration = latestTransaction?.expirationDate ?? Date.distantPast
            let newExpiration = transaction.expirationDate ?? Date.distantPast

            if latestTransaction == nil || newExpiration > currentExpiration {
                latestTransaction = transaction
            }
        }

        return latestTransaction == nil ? nil : StoreKitClient.Transaction(rawValue: latestTransaction)
    }

    // MARK: - Private Helpers

    private func fetchStoreKitProducts(for productIDs: Set<String>) async throws -> [StoreKit.Product] {
        do {
            logger("Fetching products: \(productIDs)")
            return try await StoreKit.Product.products(for: productIDs)
        } catch {
            logger("Failed to fetch products: \(error)")
            throw StoreKitClient.Error.fetchProductsFailed(productIDs: productIDs, underlyingError: error)
        }
    }

    private func fetchOrGetCachedProduct(for productID: String) async throws -> StoreKit.Product {
        if let cached = productCache[productID] {
            logger("Using cached product: \(productID)")
            return cached
        }
        let product = try await fetchSingleProduct(for: productID)
        productCache[productID] = product
        return product
    }

    private func fetchSingleProduct(for productID: String) async throws -> StoreKit.Product {
        let products = try await fetchStoreKitProducts(for: [productID])
        guard let product = products.first else {
            throw StoreKitClient.Error.productNotFound(productID: productID)
        }
        return product
    }

    private func verifiedTransaction(from result: VerificationResult<StoreKit.Transaction>) -> StoreKit.Transaction? {
        if case .verified(let transaction) = result { return transaction }
        return nil
    }

    /// Whether a transaction still grants entitlement.
    ///
    /// `currentEntitlements` usually already excludes lapsed subscriptions, but a just-expired
    /// trial or a revoked transaction can still appear briefly. Filtering here keeps
    /// `getLatestTransaction` / `restorePurchases` from reporting a lapsed trial as active.
    private func isEntitlementActive(_ transaction: StoreKit.Transaction) -> Bool {
        if transaction.revocationDate != nil { return false }
        if let expirationDate = transaction.expirationDate, expirationDate < Date() { return false }
        return true
    }

    private func deliverConsumable(
        transaction: StoreKit.Transaction,
        with handler: @Sendable (StoreKitClient.Transaction) async throws -> Void
    ) async {
        let deliveryKey = UserDefaultsKey.deliveredConsumable(transaction.id)
        guard !userDefaults.bool(forKey: deliveryKey) else {
            logger("Transaction \(transaction.id) already delivered")
            return
        }

        do {
            let wrapped = StoreKitClient.Transaction(rawValue: transaction)
            try await handler(wrapped)
            userDefaults.set(true, forKey: deliveryKey)
            await transaction.finish()
            logger("Delivered consumable \(transaction.productID)")
        } catch {
            logger("Failed to deliver consumable \(transaction.productID): \(error)")
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<StoreKit.Transaction>) async
        -> StoreKitClient.TransactionEvent
    {
        switch result {
            case .verified(let transaction):
                let wrapped = StoreKitClient.Transaction(rawValue: transaction)
                return transaction.revocationDate != nil ? .removed(wrapped) : .updated(wrapped)
            case .unverified(_, let error):
                logger("Transaction verification failed: \(error)")
                return .verificationFailed(error)
        }
    }

    private func handlePurchaseResult(_ result: StoreKit.Product.PurchaseResult) throws -> (
        StoreKitClient.Transaction, StoreKit.Transaction
    ) {
        switch result {
            case .success(let verificationResult):
                switch verificationResult {
                    case .verified(let transaction):
                        logger("Purchase succeeded for \(transaction.productID)")
                        return (StoreKitClient.Transaction(rawValue: transaction), transaction)
                    case .unverified(_, let error):
                        throw StoreKitClient.Error.unverifiedTransaction(error)
                }
            case .userCancelled:
                throw StoreKitClient.Error.userCancelled
            case .pending:
                throw StoreKitClient.Error.purchasePending
            @unknown default:
                throw StoreKitClient.Error.unknownPurchaseResult
        }
    }

    #if canImport(UIKit) && !os(watchOS)
        private func currentWindowScene() async -> UIWindowScene? {
            await UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene
        }
    #endif
}

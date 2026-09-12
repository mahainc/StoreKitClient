import Foundation
import FunnelClient
import StoreKitClient

/// Republishes subscription transactions to every `subscriptionUpdates()` caller.
///
/// Process-wide and started once, on the first subscriber. The previous design started a
/// bridge per conformer instance, so two conformers meant two loops over
/// `observeTransactions()` and the same transaction reported twice. There is one App Store
/// per process, so there is one bridge.
///
/// Only subscriptions travel here. Consumables are the credit path and are reported through
/// the purchase outcome instead; emitting them here too is how an app ends up double-counting
/// a credit pack in Adjust.
actor StoreKitSubscriptionBridge {
    static let shared = StoreKitSubscriptionBridge()

    private var continuations: [UUID: AsyncStream<FunnelClient.StoreKit.Transaction>.Continuation] = [:]
    private var bridge: Task<Void, Never>?

    func emit(_ transaction: FunnelClient.StoreKit.Transaction) {
        for continuation in continuations.values {
            continuation.yield(transaction)
        }
    }

    nonisolated func stream(for client: StoreKitClient) -> AsyncStream<FunnelClient.StoreKit.Transaction> {
        AsyncStream { continuation in
            let id = UUID()
            Task { await self.register(id: id, continuation: continuation, client: client) }
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.unregister(id: id) }
            }
        }
    }

    private func register(
        id: UUID,
        continuation: AsyncStream<FunnelClient.StoreKit.Transaction>.Continuation,
        client: StoreKitClient
    ) {
        continuations[id] = continuation
        startIfNeeded(client: client)
    }

    private func unregister(id: UUID) {
        continuations.removeValue(forKey: id)
    }

    /// Lazily, because a host that never asks for subscription updates should not pay for a
    /// permanent loop over `observeTransactions()`.
    private func startIfNeeded(client: StoreKitClient) {
        guard bridge == nil else { return }
        bridge = Task { [weak self] in
            for await event in await client.observeTransactions() {
                guard case .updated(let transaction) = event,
                    StoreKitFunnelMapping.isSubscription(transaction.productType)
                else { continue }
                let product = try? await client.loadProducts([transaction.productID]).first
                await self?.emit(StoreKitFunnelMapping.transaction(transaction, product: product))
            }
        }
    }
}

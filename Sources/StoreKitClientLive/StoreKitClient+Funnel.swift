import Dependencies
import Foundation
import FunnelClient
import LogClient
import StoreKit
import StoreKitClient

#if canImport(UIKit)
import UIKit
#endif

/// Serves `FunnelClient`'s StoreKit port from the client itself, so a host reaches it
/// through the dependency key it already has — `@Dependency(\.storeKitClient)`.
///
/// It implements **all five** requirements. Three ship a default in the port, and each
/// default is silently wrong for a real store: the credit overload drops the verifier,
/// `subscriptionUpdates()` returns an empty stream, and `startRedeliveryListener` returns a
/// task that does nothing. Inheriting any of them compiles and then loses money.
///
/// Every StoreKit decision — which product type takes which purchase path, when a
/// transaction may be finished — belongs to `StoreKitClient`; this is a translator.
extension StoreKitClient: FunnelClient.StoreKit.Providing {
    // MARK: Purchase

    public func purchase(skuID: String) async -> FunnelClient.StoreKit.Outcome {
        await buy(skuID: skuID, credit: nil)
    }

    public func purchase(
        skuID: String,
        creditGrant: UInt32,
        creditVerifier: FunnelClient.StoreKit.CreditVerifier?
    ) async -> FunnelClient.StoreKit.Outcome {
        @Dependency(\.logClient) var log
        guard let creditVerifier else {
            // A grant with nothing to verify it would take the user's money and credit
            // nothing, so it fails loudly instead of quietly buying.
            guard creditGrant == 0 else {
                log.funnel.paywall.error("purchase FAILED creditVerifier required sku=\(skuID) grant=\(creditGrant)")
                return .failed(error: "creditVerifier is required for StoreKit credit validation")
            }
            return await buy(skuID: skuID, credit: nil)
        }
        return await buy(skuID: skuID, credit: Credit(grant: creditGrant, verifier: creditVerifier))
    }

    /// The single purchase path.
    ///
    /// `credit` is a *candidate*, not a decision: it takes effect only when the loaded product
    /// is actually a consumable. Trusting the caller's grant hint instead would route a
    /// subscription through the credit verifier, and would skip crediting a consumable the
    /// backend sent a grant of 0 for.
    private func buy(
        skuID: String,
        credit: Credit?
    ) async -> FunnelClient.StoreKit.Outcome {
        @Dependency(\.logClient) var log
        guard let product = try? await self.loadProducts([skuID]).first else {
            log.funnel.paywall.error("purchase FAILED product not found sku=\(skuID)")
            return .failed(error: "product not found: \(skuID)")
        }
        do {
            let (transaction, creditOutcome) = try await run(credit: credit, on: product)
            let mapped = StoreKitFunnelMapping.transaction(transaction, product: product)
            if StoreKitFunnelMapping.isSubscription(product.type) {
                await StoreKitSubscriptionBridge.shared.emit(mapped)
            }
            guard let creditOutcome else {
                log.funnel.paywall.info(
                    "purchase completed sku=\(skuID) tx=\(mapped.transactionID) value=\(product.price) \(product.priceFormatStyle.currencyCode)"
                )
                return .completed(mapped)
            }
            log.funnel.paywall.info(
                "purchase completed (credit) sku=\(skuID) tx=\(mapped.transactionID) grant=\(creditOutcome.granted) wallet=\(creditOutcome.walletBalance)"
            )
            return .creditedFirebaseLogged(
                mapped,
                walletBalance: creditOutcome.walletBalance,
                granted: creditOutcome.granted
            )
        } catch let failure as CreditVerificationFailure {
            log.funnel.paywall.error("purchase FAILED credit verify sku=\(skuID) error=\(failure.reason)")
            return .failed(error: failure.reason)
        } catch let error as StoreKitClient.Error {
            switch error {
                case .userCancelled:
                    log.funnel.paywall.notice("purchase cancelled sku=\(skuID)")
                    return .cancelled
                case .purchasePending:
                    // Awaiting parental approval. The funnel has no "ask again later" state,
                    // and treating it as a failure would show the user an error for something
                    // that has not gone wrong.
                    log.funnel.paywall.notice("purchase pending sku=\(skuID) — treated as cancelled")
                    return .cancelled
                default:
                    log.funnel.paywall.error("purchase FAILED sku=\(skuID) error=\(error.localizedDescription)")
                    return .failed(error: error.localizedDescription)
            }
        } catch {
            log.funnel.paywall.error("purchase FAILED sku=\(skuID) error=\(error.localizedDescription)")
            return .failed(error: error.localizedDescription)
        }
    }

    /// Routes to the purchase API that matches the product's own type, and returns the credit
    /// result when one was collected.
    private func run(
        credit: Credit?,
        on product: StoreKitClient.Product
    ) async throws -> (StoreKitClient.Transaction, CreditLedger.Outcome?) {
        switch product.type {
            case .consumable:
                guard let credit else {
                    // Nothing to grant, so nothing to hold the transaction open for.
                    return (try await self.purchaseConsumable(product.id, nil) { _ in }, nil)
                }
                let ledger = CreditLedger()
                let transaction = try await self.purchaseConsumable(product.id, (funnelSettings().appAccountToken ?? Self.deviceAppAccountToken)()) { transaction in
                    switch await credit.verifier(String(transaction.id), product.id) {
                        case let .credited(walletBalance, granted):
                            await ledger.record(walletBalance: walletBalance, granted: granted)
                        case let .failed(reason):
                            // Throwing leaves the transaction unfinished on purpose: StoreKit
                            // re-delivers it and the redelivery listener retries the grant.
                            throw CreditVerificationFailure(reason: reason)
                    }
                }
                return (transaction, await ledger.outcome)
            case .autoRenewable, .nonRenewable:
                return (try await self.subscribe(product.id), nil)
            case .nonConsumable:
                return (try await self.purchase(product.id), nil)
            default:
                throw UnsupportedProductType(productType: product.type.rawValue)
        }
    }

    // MARK: Restore

    public func restore(productIDs: [String]) async throws -> FunnelClient.StoreKit.Transaction? {
        @Dependency(\.logClient) var log
        let wanted = Set(productIDs.filter { !$0.isEmpty })
        // Rethrown rather than swallowed: a sync failure means "we could not tell", which is
        // not the same answer as "you own nothing".
        try await self.syncAppStore()
        let restored = await self.restorePurchases()
        guard
            let match = restored.first(where: { wanted.contains($0.productID) })
                ?? restored.first(where: { funnelSettings().premiumProductIDs.contains($0.productID) })
        else {
            log.funnel.paywall.notice("restore found nothing to restore wanted=\(wanted.sorted())")
            return nil
        }
        let product = try? await self.loadProducts([match.productID]).first
        log.funnel.paywall.notice("restore matched product=\(match.productID) tx=\(match.id)")
        return StoreKitFunnelMapping.transaction(match, product: product)
    }

    // MARK: Streams

    public func subscriptionUpdates() -> AsyncStream<FunnelClient.StoreKit.Transaction> {
        StoreKitSubscriptionBridge.shared.stream(for: self)
    }

    public func startRedeliveryListener(
        verifier: @escaping FunnelClient.StoreKit.CreditVerifier
    ) -> Task<Void, Never> {
        self.redeliveryListener { transaction in
            switch await verifier(String(transaction.id), transaction.productID) {
                case .credited:
                    return
                case let .failed(reason):
                    throw CreditVerificationFailure(reason: reason)
            }
        }
    }

    // MARK: Support

    private struct Credit {
        let grant: UInt32
        let verifier: FunnelClient.StoreKit.CreditVerifier
    }

    /// Carries the backend's answer out of the verify closure, which can only signal failure.
    private actor CreditLedger {
        struct Outcome {
            let walletBalance: UInt32
            let granted: UInt32
        }

        private(set) var outcome: Outcome?

        func record(
            walletBalance: UInt32,
            granted: UInt32
        ) {
            outcome = Outcome(walletBalance: walletBalance, granted: granted)
        }
    }

    private struct CreditVerificationFailure: Swift.Error {
        let reason: String
    }

    /// `StoreKit.Product.ProductType` is an open struct, not a closed enum, so a type Apple
    /// adds later reaches here rather than failing to compile.
    private struct UnsupportedProductType: Swift.Error, LocalizedError {
        let productType: String

        var errorDescription: String? { "Unsupported product type: \(productType)" }
    }

    private static func deviceAppAccountToken() -> UUID? {
        #if os(iOS) && canImport(UIKit)
        return UIDevice.current.identifierForVendor
        #else
        return nil
        #endif
    }
}

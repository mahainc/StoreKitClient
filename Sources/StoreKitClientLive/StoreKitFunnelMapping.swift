import Foundation
import FunnelClient
import StoreKit
import StoreKitClient

/// Translates this package's StoreKit models into the pure types `FunnelClient` publishes.
///
/// The funnel reports revenue to Adjust and GA4 from these values, so every field it can
/// carry is filled here rather than left nil: an absent `period` or `offer` silently
/// degrades a subscription event into an untyped purchase downstream.
enum StoreKitFunnelMapping {
    /// A subscription is the only thing the funnel's subscription bridge should republish;
    /// consumables and one-time unlocks travel on the purchase path instead.
    static func isSubscription(_ productType: StoreKit.Product.ProductType) -> Bool {
        productType == .autoRenewable || productType == .nonRenewable
    }

    /// Fills all thirteen fields of the port's transaction.
    ///
    /// - Parameters:
    ///   - transaction: The verified transaction.
    ///   - product: The product it came from. Optional because a redelivered transaction can
    ///     arrive before its product has been loaded; price, currency and period then fall
    ///     back to what the transaction itself carries.
    static func transaction(
        _ transaction: StoreKitClient.Transaction,
        product: StoreKitClient.Product?
    ) -> FunnelClient.StoreKit.Transaction {
        FunnelClient.StoreKit.Transaction(
            productID: transaction.productID,
            transactionID: String(transaction.id),
            originalTransactionID: transaction.originalID.map(String.init),
            price: product?.price ?? transaction.price ?? 0,
            currency: product?.priceFormatStyle.currencyCode ?? transaction.currency ?? "",
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate,
            salesRegion: transaction.salesRegion,
            ownershipType: ownershipType(transaction.ownershipType),
            environment: environment(transaction.environment),
            period: period(product?.subscription?.subscriptionPeriod),
            offer: offer(
                appliedType: transaction.offerType,
                introductoryOffer: product?.subscription?.introductoryOffer
            ),
            productType: productType(transaction.productType)
        )
    }

    /// The field both shipping apps leave unset, which is why every subscription event
    /// downstream currently classifies as `Kind.unknown`.
    static func productType(
        _ productType: StoreKit.Product.ProductType
    ) -> FunnelClient.StoreKit.Transaction.ProductType? {
        switch productType {
            case .consumable: return .consumable
            case .nonConsumable: return .nonConsumable
            case .autoRenewable: return .autoRenewable
            case .nonRenewable: return .nonRenewing
            default: return nil
        }
    }

    private static func ownershipType(
        _ ownershipType: StoreKit.Transaction.OwnershipType?
    ) -> FunnelClient.StoreKit.Transaction.OwnershipType? {
        switch ownershipType {
            case .purchased: return .purchased
            case .familyShared: return .familyShared
            default: return nil
        }
    }

    private static func environment(
        _ environment: StoreKitClient.TransactionEnvironment
    ) -> FunnelClient.StoreKit.Transaction.Environment? {
        switch environment {
            case .sandbox: return .sandbox
            case .production: return .production
            case .xcode: return .xcode
            case .unknown: return nil
        }
    }

    private static func period(
        _ period: StoreKitClient.SubscriptionPeriod?
    ) -> FunnelClient.StoreKit.Transaction.SubscriptionPeriod? {
        guard let period else { return nil }
        let unit: FunnelClient.StoreKit.Transaction.SubscriptionPeriod.Unit
        switch period.unit {
            case .day: unit = .day
            case .week: unit = .week
            case .month: unit = .month
            case .year: unit = .year
        }
        return .init(unit: unit, value: period.value)
    }

    /// Reports an introductory offer only when the transaction says one was *applied* and the
    /// product still describes it as introductory. Either half alone is not evidence: a
    /// product can advertise an intro offer the buyer was not eligible for.
    static func offer(
        appliedType: StoreKit.Transaction.OfferType?,
        introductoryOffer: StoreKitClient.SubscriptionOffer?
    ) -> FunnelClient.StoreKit.Transaction.Offer? {
        guard appliedType == .introductory,
            let introductoryOffer,
            introductoryOffer.type == .introductory
        else { return nil }
        let paymentMode: FunnelClient.StoreKit.Transaction.Offer.PaymentMode
        switch introductoryOffer.paymentMode {
            case .freeTrial: paymentMode = .freeTrial
            case .payUpFront: paymentMode = .payUpFront
            case .payAsYouGo: paymentMode = .payAsYouGo
        }
        return .init(kind: .introductory, paymentMode: paymentMode)
    }
}

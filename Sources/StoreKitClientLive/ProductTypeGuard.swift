//
//  ProductTypeGuard.swift
//  StoreKitClient
//

import StoreKit
import StoreKitClient

/// Rejects a purchase entry point that was handed the wrong kind of product.
///
/// The three entry points sell different things and cannot be swapped: only a consumable may
/// hold `finish()` back behind a server verify, and only a subscription lapses on its own. So
/// the product's real type decides, not the call site — a paywall that points a "subscribe"
/// button at a consumable SKU should fail loudly on the first tap rather than take the money
/// and grant nothing.
///
/// - Parameters:
///   - actual: The type the App Store reports for the product.
///   - productID: The product that was asked for, for the error message.
///   - accepting: Every type this entry point serves. A subscription path takes both
///     auto-renewable and non-renewing.
///   - expected: The one type the error names, when `accepting` holds more than one.
/// - Throws: `StoreKitClient.Error.productTypeMismatch` when `actual` is not in `accepting`.
func requireProductType(
    _ actual: StoreKit.Product.ProductType,
    productID: String,
    accepting: Set<StoreKit.Product.ProductType>,
    expected: StoreKit.Product.ProductType
) throws {
    guard !accepting.contains(actual) else { return }
    throw StoreKitClient.Error.productTypeMismatch(
        productID: productID,
        expected: expected,
        actual: actual
    )
}

/// The product types each purchase entry point serves.
enum PurchaseEntryPoint {
    /// ``StoreKitClient/purchase`` — a permanent one-time unlock.
    static let nonConsumable: Set<StoreKit.Product.ProductType> = [.nonConsumable]

    /// ``StoreKitClient/subscribe`` — auto-renewable and non-renewing subscriptions alike.
    static let subscription: Set<StoreKit.Product.ProductType> = [.autoRenewable, .nonRenewable]

    /// ``StoreKitClient/purchaseConsumable`` — a grant a server records.
    static let consumable: Set<StoreKit.Product.ProductType> = [.consumable]
}

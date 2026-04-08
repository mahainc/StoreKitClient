//
//  Live.swift
//  StoreKitClient
//
//  Created by Thanh Hai Khong on 27/3/25.
//

import ComposableArchitecture
import StoreKitClient
import StoreKit

@available(iOSApplicationExtension, unavailable)
@available(iOS 15.0, *)
extension StoreKitClient: DependencyKey {
    public static let liveValue: StoreKitClient = {
        let actor = StoreKitLiveActor()
        return StoreKitClient(
            receiptURL: {
                actor.receiptURL()
            },
            canMakePayments: {
                actor.canMakePayments()
            },
            loadProducts: { productIDs in
                try await actor.loadProducts(for: productIDs)
            },
            processUnfinishedConsumables: { deliverConsumable in
                await actor.processUnfinishedConsumables(handler: deliverConsumable)
            },
            observeTransactions: {
                await actor.observeTransactions()
            },
            requestReview: {
                await actor.requestReview()
            },
            purchase: { productID in
                try await actor.purchase(productID: productID)
            },
            restorePurchases: {
                await actor.restorePurchases()
            },
            getLatestTransaction: {
                await actor.getLatestTransaction()
            },
            isEligibleForIntroOffer: { groupID in
                await actor.isEligibleForIntroOffer(groupID: groupID)
            }
        )
    }()
}

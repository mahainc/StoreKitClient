//
//  Live.swift
//  StoreKitClient
//
//  Created by Thanh Hai Khong on 27/3/25.
//

import Dependencies
import StoreKit
import StoreKitClient

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
            subscribe: { productID in
                try await actor.subscribe(productID: productID)
            },
            purchaseConsumable: { productID, appAccountToken, verify in
                try await actor.purchaseConsumable(
                    productID: productID,
                    appAccountToken: appAccountToken,
                    verify: verify
                )
            },
            redeliveryListener: { verify in
                actor.redeliveryListener(verify: verify)
            },
            syncAppStore: {
                try await actor.syncAppStore()
            },
            restorePurchases: {
                await actor.restorePurchases()
            },
            getLatestTransaction: {
                await actor.getLatestTransaction()
            },
            isEligibleForIntroOffer: { groupID in
                await actor.isEligibleForIntroOffer(groupID: groupID)
            },
            currentSubscriptionStatus: { groupID in
                await actor.currentSubscriptionStatus(groupID: groupID)
            },
            observeSubscriptionStatus: { groupID in
                await actor.observeSubscriptionStatus(groupID: groupID)
            }
        )
    }()
}

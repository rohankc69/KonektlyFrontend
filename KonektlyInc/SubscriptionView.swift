//
//  SubscriptionView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI
import Combine

struct SubscriptionView: View {
    @StateObject private var manager = SubscriptionManager.shared
    
    var body: some View {
        Group {
            if manager.isKonektlyPlus {
                KonektlyPlusActiveView(
                    expiresAt: manager.subscriptionStatus?.expiresAt,
                    status: manager.subscriptionStatus?.status ?? "",
                    onManage: { manager.openCancellationPage() }
                )
            } else {
                UpgradeView(
                    price: manager.displayPrice,
                    isPurchasing: manager.isPurchasing,
                    isLoadingProduct: manager.isLoadingProduct,
                    onPurchase: { Task { await manager.purchase() } },
                    onRestore: { Task { await manager.restorePurchases() } },
                    onRetry: { Task { await manager.loadProduct() } }
                )
            }
        }
        .task {
            if manager.storeKitProduct == nil && !manager.isLoadingProduct {
                await manager.loadProduct()
            }
        }
        .alert("Error", isPresented: .constant(manager.error != nil)) {
            Button("OK") { manager.error = nil }
        } message: {
            Text(manager.error ?? "")
        }
    }
}

#Preview {
    SubscriptionView()
}

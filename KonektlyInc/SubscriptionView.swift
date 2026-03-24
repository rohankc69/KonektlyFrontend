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
                    onPurchase: { Task { await manager.purchase() } },
                    onRestore: { Task { await manager.restorePurchases() } }
                )
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

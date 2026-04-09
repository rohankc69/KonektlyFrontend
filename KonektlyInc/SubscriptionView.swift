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
    @State private var showErrorAlert = false
    
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
                    isRestoring: manager.isRestoring,
                    isLoadingProduct: manager.isLoadingProduct,
                    onPurchase: { Task { @MainActor in await manager.purchase() } },
                    onRestore: { Task { await manager.restorePurchases() } },
                    onRetry: { Task { await manager.loadProduct() } }
                )
                .onAppear {
                    // Sticky banner is client-only; opening paywall clears it so Subscribe isn’t blocked.
                    manager.clearPurchaseSyncBannerIfNotBusy()
                }
            }
        }
        .task {
            if manager.storeKitProduct == nil && !manager.isLoadingProduct {
                await manager.loadProduct()
            }
        }
        .onChange(of: manager.error) { _, newValue in
            showErrorAlert = (newValue != nil)
        }
        .overlay(alignment: .top) {
            if let notice = manager.syncNotice, !notice.isEmpty {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(Theme.Colors.accent)
                    Text(notice)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Button {
                        manager.syncNotice = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.lg)
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") { manager.error = nil }
        } message: {
            Text(manager.error ?? "")
        }
        .alert(item: Binding(
            get: { manager.restoreResultAlert },
            set: { manager.restoreResultAlert = $0 }
        )) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    SubscriptionView()
}

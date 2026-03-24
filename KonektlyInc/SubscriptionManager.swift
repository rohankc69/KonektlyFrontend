//
//  SubscriptionManager.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import Foundation
import StoreKit
import Combine

@MainActor
final class SubscriptionManager: ObservableObject {
    
    static let shared = SubscriptionManager()
    
    // Product ID must match what's in App Store Connect + backend APPLE_PRODUCT_ID_KONEKTLY_PLUS
    private let productID = "com.konektly.plus.monthly"
    
    @Published var subscriptionStatus: SubscriptionStatus?
    @Published var storeKitProduct: Product?
    @Published var isPurchasing = false
    @Published var error: String?
    
    private var transactionListener: Task<Void, Never>?
    
    init() {
        transactionListener = listenForTransactions()
        Task {
            await loadProduct()
            await refreshSubscriptionStatus()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Load product from App Store
    
    func loadProduct() async {
        do {
            let products = try await Product.products(for: [productID])
            storeKitProduct = products.first
        } catch {
            self.error = "Could not load subscription details."
        }
    }
    
    // MARK: - Purchase
    
    func purchase() async {
        guard let product = storeKitProduct else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await sendToBackend(verification: verification)
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                // Payment pending (e.g. Ask to Buy) - wait for listenForTransactions
                break
            @unknown default:
                break
            }
        } catch {
            self.error = "Purchase failed. Please try again."
        }
    }
    
    // MARK: - Send verified transaction to backend

    // Accepts VerificationResult<Transaction> because jwsRepresentation is on the
    // wrapper, not on the unwrapped Transaction. The caller holds the Transaction
    // for finish().
    private func sendToBackend(verification: VerificationResult<Transaction>) async {
        let jws = verification.jwsRepresentation
        do {
            let status = try await APIClient.shared.validateAppleTransaction(
                jwsTransaction: jws
            )
            self.subscriptionStatus = status
        } catch {
            // Transaction is valid with Apple but backend call failed.
            // Retry on next app launch via refreshSubscriptionStatus().
            self.error = "Purchase successful — syncing your account. Please wait."
            await refreshSubscriptionStatus()
        }
    }
    
    // MARK: - Listen for background transactions (renewals, restored purchases)
    
    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    await sendToBackend(verification: result)
                    await transaction.finish()
                } catch {
                    // Invalid transaction from Apple — ignore unverified
                }
            }
        }
    }
    
    // MARK: - Fetch subscription status from backend
    
    func refreshSubscriptionStatus() async {
        do {
            subscriptionStatus = try await APIClient.shared.fetchSubscriptionStatus()
        } catch {
            // Keep existing cached status if request fails
        }
    }
    
    // MARK: - Cancel (directs to App Store - Apple manages cancellation)
    
    func openCancellationPage() {
        // Apple requires cancellations go through the App Store subscription settings.
        // Do NOT call the backend cancel endpoint from iOS - Apple manages billing.
        Task {
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first {
                try? await AppStore.showManageSubscriptions(in: windowScene)
            }
        }
    }
    
    // MARK: - Restore purchases (required by App Store guidelines)
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshSubscriptionStatus()
        } catch {
            self.error = "Could not restore purchases."
        }
    }
    
    // MARK: - Verify StoreKit result
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }
    
    // MARK: - Computed helpers
    
    var isKonektlyPlus: Bool {
        subscriptionStatus?.isKonektlyPlus ?? false
    }
    
    var displayPrice: String {
        storeKitProduct?.displayPrice ?? ""
    }
}

enum StoreError: Error {
    case failedVerification
}

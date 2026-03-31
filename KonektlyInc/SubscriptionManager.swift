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
    private let productID = "com.konektly.app.konektlyplus.monthly"
    
    @Published var subscriptionStatus: SubscriptionStatus?
    @Published var storeKitProduct: Product?
    @Published var isPurchasing = false
    @Published var isLoadingProduct = false
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
        guard !isLoadingProduct else { return }
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        print("[SUB] Loading products (APPLE_MODE=\(Config.appleMode.rawValue))")
        do {
            let products = try await Product.products(for: [productID])
            guard let product = products.first else {
                print("[SUB] No StoreKit product returned for productID=\(productID) (APPLE_MODE=\(Config.appleMode.rawValue))")
                self.error = "Subscription product not found. Check App Store Connect configuration."
                return
            }
            storeKitProduct = product
            self.error = nil
            print("[SUB] Product loaded (id=\(product.id), price=\(product.displayPrice), APPLE_MODE=\(Config.appleMode.rawValue))")
        } catch {
            print("[SUB] Product load failed (APPLE_MODE=\(Config.appleMode.rawValue), error=\(error.localizedDescription))")
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
                let jwsTransaction = verification.jwsRepresentation

                do {
                    try await validateAndRefreshFromBackend(
                        jwsTransaction: jwsTransaction,
                        source: "purchase"
                    )
                    await transaction.finish()
                    print("[SUB] Purchase synced + finished (APPLE_MODE=\(Config.appleMode.rawValue))")
                } catch {
                    handleSubscriptionSyncFailure(
                        error,
                        source: "purchase",
                        showUserMessage: true
                    )
                    // Do NOT finish on sync failure. Leaving it unfinished lets
                    // StoreKit re-deliver via Transaction.updates for retry.
                }
            case .userCancelled:
                print("[SUB] Purchase cancelled by user (APPLE_MODE=\(Config.appleMode.rawValue))")
                break
            case .pending:
                // Payment pending (e.g. Ask to Buy) - wait for listenForTransactions
                print("[SUB] Purchase pending (APPLE_MODE=\(Config.appleMode.rawValue))")
                break
            @unknown default:
                break
            }
        } catch {
            self.error = "Purchase failed. Please try again."
        }
    }
    
    // MARK: - Backend sync (source of truth = /subscriptions/me/)

    private func validateAndRefreshFromBackend(
        jwsTransaction: String,
        source: String
    ) async throws {
        let mode = Config.appleMode.rawValue
        print("[SUB] Validate start (APPLE_MODE=\(mode), source=\(source))")

        _ = try await APIClient.shared.validateAppleTransaction(
            jwsTransaction: jwsTransaction
        )
        print("[SUB] Validate success (APPLE_MODE=\(mode), source=\(source))")

        let backendStatus = try await APIClient.shared.fetchSubscriptionStatus()
        subscriptionStatus = backendStatus
        print("[SUB] Status refresh success (APPLE_MODE=\(mode), source=\(source), plan=\(backendStatus.plan), status=\(backendStatus.status), plus=\(backendStatus.isKonektlyPlus))")
    }
    
    // MARK: - Listen for background transactions (renewals, restored purchases)
    
    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    try await validateAndRefreshFromBackend(
                        jwsTransaction: result.jwsRepresentation,
                        source: "transaction_update"
                    )
                    await transaction.finish()
                    print("[SUB] Update synced + finished (APPLE_MODE=\(Config.appleMode.rawValue))")
                } catch {
                    handleSubscriptionSyncFailure(
                        error,
                        source: "transaction_update",
                        showUserMessage: false
                    )
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

    // MARK: - Error Mapping

    private func handleSubscriptionSyncFailure(
        _ error: Error,
        source: String,
        showUserMessage: Bool
    ) {
        let mode = Config.appleMode.rawValue
        let message: String

        switch error {
        case AppError.unauthorized:
            message = "Session expired. Please sign in again."
            print("[SUB] Sync failed unauthorized (APPLE_MODE=\(mode), source=\(source))")
        case AppError.network:
            message = "Purchase succeeded, but we couldn't reach the server. We'll retry shortly."
            print("[SUB] Sync failed network (APPLE_MODE=\(mode), source=\(source))")
        case AppError.apiError(let code, _):
            message = "Purchase received, but validation failed (\(code.rawValue)). Please try again."
            print("[SUB] Sync failed API error (APPLE_MODE=\(mode), source=\(source), code=\(code.rawValue))")
        case AppError.decoding:
            message = "Purchase received, but server response was unexpected. Please try again."
            print("[SUB] Sync failed decode (APPLE_MODE=\(mode), source=\(source))")
        default:
            message = "Purchase received, but we couldn't sync your subscription yet."
            print("[SUB] Sync failed unknown (APPLE_MODE=\(mode), source=\(source), error=\(String(describing: error)))")
        }

        if showUserMessage {
            self.error = message
        }
    }
}

enum StoreError: Error {
    case failedVerification
}

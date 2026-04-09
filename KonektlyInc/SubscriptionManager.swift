//
//  SubscriptionManager.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import Foundation
import StoreKit
import Combine

/// Shown after Restore Purchases completes (success, nothing found, or account mismatch).
struct SubscriptionRestoreAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    /// Product ID must match App Store Connect + backend `APPLE_PRODUCT_ID_KONEKTLY_PLUS`
    private let productID = "com.konektly.app.konektlyplus.monthly"

    @Published var subscriptionStatus: SubscriptionStatus?
    @Published var storeKitProduct: Product?
    @Published var isPurchasing = false
    @Published var isRestoring = false
    @Published var isLoadingProduct = false
    @Published var error: String?
    @Published var syncNotice: String?
    @Published var restoreResultAlert: SubscriptionRestoreAlert?

    /// Cached for the session; cleared on logout (re-fetch before first purchase after login).
    private var cachedAppAccountToken: UUID?

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

    /// Call on logout / account switch. Does not stop StoreKit.
    func clearSessionSubscriptionCaches() {
        cachedAppAccountToken = nil
        subscriptionStatus = nil
        syncNotice = nil
        error = nil
        restoreResultAlert = nil
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
        // New attempt: don’t leave the UI stuck in “confirming” with Subscribe disabled.
        syncNotice = nil
        error = nil

        if storeKitProduct == nil {
            await loadProduct()
        }
        guard let product = storeKitProduct else {
            error = "Couldn’t load subscription from the App Store. Check your connection, then use Try Again."
            print("[SUB] purchase aborted — no StoreKit product after load")
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        let appAccountToken: UUID
        do {
            if let cached = cachedAppAccountToken {
                appAccountToken = cached
            } else {
                let token = try await APIClient.shared.fetchAppleAppAccountToken()
                cachedAppAccountToken = token
                appAccountToken = token
            }
        } catch {
            print("[SUB] account-token fetch failed: \(error)")
            self.error = messageForAccountTokenFailure(error)
            return
        }

        do {
            let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                let jwsTransaction = verification.jwsRepresentation

                do {
                    try await validateAndRefreshFromBackend(
                        jwsTransaction: jwsTransaction,
                        source: "purchase"
                    )
                    syncNotice = nil
                    error = nil
                    await transaction.finish()
                    print("[SUB] Purchase synced + finished (APPLE_MODE=\(Config.appleMode.rawValue))")
                } catch {
                    print("[SUB] Validate failed source=purchase err=\(error)")
                    handlePurchaseValidateFailure(error)
                }
            case .userCancelled:
                print("[SUB] Purchase cancelled by user (APPLE_MODE=\(Config.appleMode.rawValue))")
            case .pending:
                print("[SUB] Purchase pending (APPLE_MODE=\(Config.appleMode.rawValue))")
            @unknown default:
                break
            }
        } catch {
            self.error = "Purchase failed. Please try again."
        }
    }

    // MARK: - Backend sync (source of truth = GET /subscriptions/me/)

    private func validateAndRefreshFromBackend(
        jwsTransaction: String,
        source: String
    ) async throws {
        let mode = Config.appleMode.rawValue
        print("[SUB] Validate start (APPLE_MODE=\(mode), source=\(source))")

        _ = try await APIClient.shared.validateAppleTransaction(jwsTransaction: jwsTransaction)
        print("[SUB] Validate success (APPLE_MODE=\(mode), source=\(source))")

        let backendStatus = try await APIClient.shared.fetchSubscriptionStatus()
        subscriptionStatus = backendStatus
        print("[SUB] Status refresh success (APPLE_MODE=\(mode), source=\(source), plan=\(backendStatus.plan), status=\(backendStatus.status), plus=\(backendStatus.isKonektlyPlus))")
    }

    // MARK: - Transaction updates (renewals, Ask-to-Buy, etc.)

    private func listenForTransactions() -> Task<Void, Never> {
        let pid = productID
        return Task(priority: .background) {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }

                if transaction.productID != pid {
                    await transaction.finish()
                    continue
                }

                do {
                    _ = try await APIClient.shared.validateAppleTransaction(jwsTransaction: result.jwsRepresentation)
                    await transaction.finish()
                    await SubscriptionManager.shared.refreshSubscriptionStatus()
                    print("[SUB] Update synced + finished (APPLE_MODE=\(Config.appleMode.rawValue))")
                } catch {
                    if shouldStopRetryingTransaction(for: error) {
                        await transaction.finish()
                        let capturedError = error
                        await MainActor.run {
                            self.syncNotice = nil
                            self.error = self.mapValidateErrorToUserMessage(capturedError)
                                ?? "This purchase can't be applied to this account. Please try again or contact support."
                        }
                        print("[SUB] Stopped retry for permanent error: \(error)")
                        continue
                    }
                    print("[SUB] Background validate failed: \(error)")
                }
            }
        }
    }

    // MARK: - Fetch subscription status from backend

    func refreshSubscriptionStatus() async {
        do {
            subscriptionStatus = try await APIClient.shared.fetchSubscriptionStatus()
            if subscriptionStatus?.isKonektlyPlus == true {
                syncNotice = nil
            }
        } catch {
            // Keep existing cached status if request fails
        }
    }

    /// Re-send JWS for unfinished StoreKit transactions (e.g. validate failed earlier). Safe to call from foreground.
    func retryValidateUnfinishedTransactions(source: String = "retry") async {
        let pid = productID
        for await verification in Transaction.unfinished {
            guard case .verified(let transaction) = verification else { continue }
            guard transaction.productID == pid else { continue }
            do {
                try await validateAndRefreshFromBackend(
                    jwsTransaction: verification.jwsRepresentation,
                    source: source
                )
                await transaction.finish()
                error = nil
                syncNotice = nil
                print("[SUB] Unfinished transaction validated (source=\(source))")
            } catch {
                if shouldStopRetryingTransaction(for: error) {
                    await transaction.finish()
                    syncNotice = nil
                    self.error = mapValidateErrorToUserMessage(error)
                        ?? "This purchase can't be applied to this account. Please try again or contact support."
                    print("[SUB] Finished unfinished transaction (permanent error): \(error)")
                    continue
                }
                print("[SUB] Unfinished validate still failing (source=\(source)): \(error)")
            }
        }
    }

    // MARK: - Cancel (App Store subscription management)

    func openCancellationPage() {
        Task {
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first {
                try? await AppStore.showManageSubscriptions(in: windowScene)
            }
        }
    }

    // MARK: - Restore purchases

    func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }
        restoreResultAlert = nil
        error = nil

        var syncFailed = false
        do {
            try await AppStore.sync()
        } catch {
            syncFailed = true
            print("[SUB] AppStore.sync failed — using cached entitlements: \(error.localizedDescription)")
        }

        var restoredAny = false
        var hitAccountMismatch = false
        // True if we found a valid entitlement candidate but couldn’t reach our server to confirm it.
        var serverUnreachable = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == productID else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expiration = transaction.expirationDate, expiration < Date() { continue }

            do {
                _ = try await APIClient.shared.validateAppleTransaction(jwsTransaction: result.jwsRepresentation)
                restoredAny = true
            } catch let err {
                if shouldStopRetryingTransaction(for: err) {
                    print("[SUB] Ignoring permanent-error restore transaction: \(err)")
                    continue
                }
                if isSubscriptionAccountMismatch(err) {
                    hitAccountMismatch = true
                } else {
                    // We found a candidate entitlement but the server was unreachable or returned a transient error.
                    serverUnreachable = true
                    print("[SUB] Restore validate failed: \(err)")
                }
            }
        }

        await refreshSubscriptionStatus()

        if restoredAny {
            restoreResultAlert = SubscriptionRestoreAlert(
                title: "Purchases Restored",
                message: "Your Konektly+ subscription has been restored."
            )
        } else if hitAccountMismatch {
            restoreResultAlert = SubscriptionRestoreAlert(
                title: "Different Account",
                message: "This Apple ID has Konektly+ linked to a different Konektly account. Log in with that account to use your subscription, or purchase a new one."
            )
        } else if serverUnreachable {
            // We found entitlement(s) but couldn’t reach the Konektly backend to confirm them.
            restoreResultAlert = SubscriptionRestoreAlert(
                title: "Couldn’t Connect to Server",
                message: "We found a purchase on this Apple ID but couldn’t reach the Konektly server to confirm it. Check your internet connection and tap Restore Purchases again."
            )
        } else {
            // Either nothing to restore, or AppStore.sync() failed but local cache also has nothing.
            // syncFailed alone is not shown as an error since Transaction.currentEntitlements is local.
            restoreResultAlert = SubscriptionRestoreAlert(
                title: "Nothing to Restore",
                message: "We couldn’t find any active Konektly+ purchases on this Apple ID."
            )
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

    /// Authoritative entitlement: backend only (never StoreKit alone).
    var isKonektlyPlus: Bool {
        subscriptionStatus?.isKonektlyPlus == true
    }

    var displayPrice: String {
        storeKitProduct?.displayPrice ?? ""
    }

    // MARK: - Error mapping

    private func messageForAccountTokenFailure(_ error: Error) -> String {
        switch error {
        case AppError.unauthorized:
            return "Session expired. Please sign in again."
        case AppError.network:
            return "No internet connection. Connect and try again."
        case AppError.decoding:
            return "Couldn’t read subscription setup from the server. Please try again or update the app."
        case AppError.apiError(_, let message) where !message.isEmpty:
            return message
        case AppError.serviceUnavailable(let message):
            return message.isEmpty ? "Service is temporarily unavailable. Try again later." : message
        default:
            return "Could not prepare purchase. Please sign in and try again."
        }
    }

    private func isSubscriptionAccountMismatch(_ error: Error) -> Bool {
        let msg: String?
        switch error {
        case AppError.apiError(_, let message):
            msg = message
        case AppError.conflict(let message):
            msg = message
        default:
            msg = (error as? LocalizedError)?.errorDescription
        }
        guard let text = msg?.lowercased() else { return false }
        return text.contains("does not belong to this account")
            || text.contains("already in use by another account")
    }

    /// Maps known /validate/ error bodies to user-facing copy. Returns nil to fall back to sync/retry handling.
    private func mapValidateErrorToUserMessage(_ error: Error) -> String? {
        let raw: String
        switch error {
        case AppError.apiError(_, let message):
            raw = message
        case AppError.conflict(let message):
            raw = message
        case AppError.serviceUnavailable(let message):
            if message.localizedCaseInsensitiveContains("Apple IAP is not configured") {
                return "Subscriptions are temporarily unavailable."
            }
            return nil
        default:
            return nil
        }

        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.localizedCaseInsensitiveContains("Invalid or unverifiable Apple") {
            return "We couldn't verify your purchase. Try again or contact support."
        }
        if t.localizedCaseInsensitiveContains("revoked") {
            return "This purchase was refunded by Apple."
        }
        if t.localizedCaseInsensitiveContains("Family-shared purchases are not") {
            return "Konektly+ must be purchased on the account that will use it. Family Sharing isn't supported."
        }
        if t.localizedCaseInsensitiveContains("already expired") {
            return "This subscription has expired."
        }
        if t.localizedCaseInsensitiveContains("appAccountToken") || t.localizedCaseInsensitiveContains("app_account_token") {
            return "Your previous subscription can no longer be verified. Please subscribe again — your old purchase has been removed."
        }
        if isSubscriptionAccountMismatch(error) {
            return "This Apple ID already has Konektly+ linked to a different Konektly account. Log in with that account to use your subscription, or purchase a new one."
        }
        if t.localizedCaseInsensitiveContains("Failed to activate") {
            return "Something went wrong. Contact support."
        }
        if t.localizedCaseInsensitiveContains("Apple IAP is not configured") {
            return "Subscriptions are temporarily unavailable."
        }
        return nil
    }

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
            if showUserMessage { self.error = message }
        case AppError.network(underlying: _):
            message = "Purchase succeeded, but we couldn't reach the server. We'll keep trying in the background—tap Restore Purchases if access doesn't appear."
            print("[SUB] Sync failed network (APPLE_MODE=\(mode), source=\(source))")
            self.syncNotice = "Purchase received. Syncing with server in background."
            if showUserMessage { self.error = nil }
            scheduleBackgroundStatusRetry()
        case AppError.apiError(let code, _):
            message = "Purchase succeeded, but we're still confirming it with our server. Tap Restore Purchases if needed."
            print("[SUB] Sync failed API error (APPLE_MODE=\(mode), source=\(source), code=\(code.rawValue))")
            self.syncNotice = "Purchase received. Final confirmation is in progress."
            if showUserMessage { self.error = nil }
            scheduleBackgroundStatusRetry()
        case AppError.decoding:
            message = "Purchase succeeded, but we're still confirming it with our server. Tap Restore Purchases if needed."
            print("[SUB] Sync failed decode (APPLE_MODE=\(mode), source=\(source))")
            self.syncNotice = "Purchase received. Final confirmation is in progress."
            if showUserMessage { self.error = nil }
            scheduleBackgroundStatusRetry()
        default:
            message = "Purchase succeeded, but we couldn't sync your subscription yet. Tap Restore Purchases if needed."
            print("[SUB] Sync failed unknown (APPLE_MODE=\(mode), source=\(source), error=\(String(describing: error)))")
            self.syncNotice = "Purchase received. Syncing with server in background."
            if showUserMessage { self.error = nil }
            scheduleBackgroundStatusRetry()
        }
    }

    private func scheduleBackgroundStatusRetry() {
        Task { @MainActor in
            for delayNs in [2, 5, 10, 20].map({ UInt64($0) * 1_000_000_000 }) {
                try? await Task.sleep(nanoseconds: delayNs)
                await retryValidateUnfinishedTransactions(source: "background_retry")
                await refreshSubscriptionStatus()
                if subscriptionStatus?.isKonektlyPlus == true {
                    syncNotice = nil
                    error = nil
                    return
                }
            }
            // No server "pending" row drives this — it’s local UI. Clear so Subscribe isn’t blocked forever.
            if syncNotice != nil, subscriptionStatus?.isKonektlyPlus != true {
                syncNotice = nil
                if error == nil || (error?.isEmpty ?? true) {
                    error = "We couldn’t confirm the last purchase with our servers after several tries. Try Subscribe again or Restore Purchases."
                }
            }
        }
    }

    /// Clears the sticky “confirming purchase” banner when opening the paywall (no StoreKit work in flight).
    func clearPurchaseSyncBannerIfNotBusy() {
        guard !isPurchasing, !isRestoring else { return }
        syncNotice = nil
    }

    /// After StoreKit succeeds, backend /validate/ may fail temporarily (network, 5xx). Otherwise show the real error — not a fake “confirming” banner.
    private func handlePurchaseValidateFailure(_ error: Error) {
        if let mapped = mapValidateErrorToUserMessage(error) {
            self.error = mapped
            syncNotice = nil
            return
        }
        if shouldTreatValidateFailureAsTransient(error) {
            handleSubscriptionSyncFailure(error, source: "purchase", showUserMessage: true)
            Task { await retryValidateUnfinishedTransactions(source: "after_purchase") }
            return
        }
        syncNotice = nil
        switch error {
        case AppError.unauthorized:
            self.error = "Session expired. Please sign in again."
        case AppError.apiError(_, let message) where !message.isEmpty:
            self.error = message
        case AppError.conflict(let message):
            self.error = message.isEmpty ? "This purchase can’t be applied to this account." : message
        case AppError.rateLimited(let retryAfter):
            if let seconds = retryAfter {
                self.error = "Too many attempts. Wait \(Int(seconds)) seconds and try again."
            } else {
                self.error = "Too many attempts. Please wait a moment."
            }
        default:
            self.error = (error as? LocalizedError)?.errorDescription
                ?? "We couldn’t verify this purchase. Try Restore Purchases or contact support."
        }
    }

    private func shouldTreatValidateFailureAsTransient(_ error: Error) -> Bool {
        switch error {
        case AppError.network:
            return true
        case AppError.decoding:
            return true
        case AppError.serviceUnavailable:
            return true
        case AppError.apiError(let code, _):
            switch code {
            case .internalServerError, .serverError:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }

    /// Returns true for errors that are permanent — retrying will never succeed, so the transaction
    /// should be finished locally to prevent StoreKit from redelivering it on every app launch.
    private func shouldStopRetryingTransaction(for error: Error) -> Bool {
        switch error {
        case AppError.conflict:
            // 409 — subscription already tied to another account; permanent.
            return true
        case AppError.apiError(_, let message):
            let t = message.lowercased()
            // Legacy pre-token transactions (no appAccountToken embedded)
            if t.contains("missing appaccounttoken")
                || t.contains("missing app_account_token")
                || t.contains("appaccounttoken")
                || t.contains("update the konektly ios app")
                || t.contains("update the konektly app") {
                return true
            }
            // 403 — transaction belongs to a different Konektly account; permanent.
            if t.contains("does not belong to this account") { return true }
            // 409 routed through apiError
            if t.contains("already in use by another account") { return true }
            return false
        default:
            return false
        }
    }
}

enum StoreError: Error {
    case failedVerification
}

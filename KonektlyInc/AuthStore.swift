//
//  AuthStore.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import Foundation
import Combine
import FirebaseAuth

// MARK: - Auth State

enum AuthState {
    case unauthenticated
    case authenticated(user: AuthUser)
}

// MARK: - Auth Store

@MainActor
final class AuthStore: ObservableObject {
    static let shared = AuthStore()
    private init() {}

    // MARK: Published State
    @Published var authState: AuthState = .unauthenticated
    @Published var profileStatus: ProfileStatus? = nil
    @Published var accessTier: AccessTier? = nil
    @Published var isLoading = false
    @Published var error: AppError? = nil

    /// Firebase verification ID returned after OTP is sent
    private var firebaseVerificationID: String?

    var currentUser: AuthUser? {
        if case .authenticated(let user) = authState { return user }
        return nil
    }

    var isAuthenticated: Bool { currentUser != nil }

    var needsEmailVerification: Bool {
        guard let user = currentUser else { return false }
        return !user.emailVerified
    }

    var needsProfile: Bool {
        guard let user = currentUser else { return false }
        let role = UserRole(rawValue: user.role ?? "") ?? .worker
        switch role {
        case .worker: return !(profileStatus?.hasWorkerProfile ?? user.hasWorkerProfile)
        case .business: return !(profileStatus?.hasBusinessProfile ?? user.hasBusinessProfile)
        }
    }

    // MARK: - Bootstrap (called on app launch if tokens exist)

    func bootstrapIfNeeded() async {
        guard TokenStore.shared.accessToken != nil else { return }
        await loadCurrentUser()
    }

    // MARK: - Send OTP (Firebase sends the SMS)

    func sendOTP(phone: String) async throws {
        isLoading = true
        defer { isLoading = false }
        clearError()

        do {
            // Firebase will use APNs silent push or fall back to reCAPTCHA
            let verificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(phone, uiDelegate: nil)
            self.firebaseVerificationID = verificationID
            print("[AUTH] OTP sent to \(phone)")
        } catch {
            let nsError = error as NSError
            print("[AUTH] sendOTP error code: \(nsError.code)")
            print("[AUTH] sendOTP error domain: \(nsError.domain)")
            print("[AUTH] sendOTP error userInfo: \(nsError.userInfo)")
            throw AppError.apiError(code: .unknown, message: error.localizedDescription)
        }
    }

    // MARK: - Verify OTP (Firebase -> get ID token -> send to backend)

    func verifyOTPWithFirebase(phone: String, otpCode: String) async throws {
        guard let verificationID = firebaseVerificationID else {
            throw AppError.apiError(code: .unknown, message: "No verification ID. Please resend the code.")
        }

        isLoading = true
        defer { isLoading = false }
        clearError()

        // Step 1: Create Firebase credential from the OTP code
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: otpCode
        )

        // Step 2: Sign in with Firebase to validate the code
        let authResult: AuthDataResult
        do {
            authResult = try await Auth.auth().signIn(with: credential)
            print("[AUTH] Firebase sign-in succeeded")
        } catch {
            print("[AUTH] Firebase verify error: \(error.localizedDescription)")
            throw AppError.apiError(code: .otpInvalid, message: "Invalid verification code. Please try again.")
        }

        // Step 3: Get the Firebase ID token (force refresh to avoid stale cache)
        guard let idToken = try? await authResult.user.getIDTokenResult(forcingRefresh: true).token else {
            throw AppError.apiError(code: .unknown, message: "Failed to get Firebase ID token.")
        }
        print("[AUTH] Got Firebase ID token")

        // Step 4: Use Firebase's phone number (guaranteed E.164 format) to avoid mismatch
        let verifiedPhone = authResult.user.phoneNumber ?? phone

        // Step 5: Send the ID token to your backend for JWT exchange
        let tokens: AuthTokenResponse = try await APIClient.shared.publicRequest(
            .verifyOTPFirebase(phone: verifiedPhone, idToken: idToken)
        )
        storeTokens(tokens)
        await loadCurrentUser()
    }

    // MARK: - Verify OTP (Dev fallback - only available in DEBUG builds)

    func verifyOTPDev(phone: String, code: String) async throws {
        guard Config.isDevOTPFallbackEnabled else {
            throw AppError.apiError(code: .unknown, message: "Dev fallback is not available in production.")
        }
        isLoading = true
        defer { isLoading = false }
        clearError()

        let tokens: AuthTokenResponse = try await APIClient.shared.publicRequest(
            .verifyOTPDev(phone: phone, code: code)
        )
        storeTokens(tokens)
        await loadCurrentUser()
    }

    // MARK: - Load Current User

    func loadCurrentUser() async {
        do {
            let user: AuthUser = try await APIClient.shared.request(.me)
            authState = .authenticated(user: user)
            await loadProfileStatus()
        } catch AppError.unauthorized {
            signOut()
        } catch {
            self.error = error as? AppError ?? .unknown
        }
    }

    // MARK: - Email Verification

    func sendEmailVerification(email: String) async throws {
        isLoading = true
        defer { isLoading = false }
        clearError()

        let _: EmailVerificationResponse = try await APIClient.shared.request(
            .sendEmailVerification(email: email)
        )
    }

    func verifyEmailToken(_ token: String) async throws {
        isLoading = true
        defer { isLoading = false }
        clearError()

        let _: EmailVerificationResponse = try await APIClient.shared.request(
            .verifyEmailToken(token)
        )
        // Refresh user to reflect updated email_verified flag
        await loadCurrentUser()
    }

    // MARK: - Profile Creation

    func createWorkerProfile(_ request: WorkerProfileCreateRequest) async throws {
        isLoading = true
        defer { isLoading = false }
        clearError()

        let _: ProfileCreateResponse = try await APIClient.shared.request(
            .createWorkerProfile(request)
        )
        await loadCurrentUser()
    }

    func createBusinessProfile(_ request: BusinessProfileCreateRequest) async throws {
        isLoading = true
        defer { isLoading = false }
        clearError()

        let _: ProfileCreateResponse = try await APIClient.shared.request(
            .createBusinessProfile(request)
        )
        await loadCurrentUser()
    }

    // MARK: - Profile Status

    func loadProfileStatus() async {
        do {
            let status: ProfileStatus = try await APIClient.shared.request(.profileStatus)
            profileStatus = status
            let tier: AccessTier = try await APIClient.shared.request(.accessTier)
            accessTier = tier
        } catch {
            // Non-fatal; keep existing status
        }
    }

    // MARK: - Sign Out

    func signOut() {
        TokenStore.shared.clearAll()
        authState = .unauthenticated
        profileStatus = nil
        accessTier = nil
        clearError()
    }

    // MARK: - Helpers

    private func storeTokens(_ tokens: AuthTokenResponse) {
        TokenStore.shared.accessToken = tokens.access
        TokenStore.shared.refreshToken = tokens.refresh
    }

    func clearError() { error = nil }

    // Allow views to surface arbitrary errors into the store
    func setError(_ err: AppError) { error = err }
}

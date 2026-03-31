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

// MARK: - Onboarding Step

enum OnboardingStep: Int, Comparable {
    case name = 0            // needs to set first/last name
    case dob = 1             // needs to set date of birth
    case terms = 2           // needs to accept terms
    case privacy = 3         // needs to accept privacy policy
    case profileDetails = 4  // needs to submit gov ID / business details
    case complete = 5        // all done, dashboard access

    static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Auth Store

@MainActor
final class AuthStore: ObservableObject {
    static let shared = AuthStore()
    private init() {}

    @Published var authState: AuthState = .unauthenticated
    @Published var profileStatus: ProfileStatus? = nil
    @Published var accessTier: AccessTier? = nil
    @Published var isLoading = false
    @Published var error: AppError? = nil

    private var firebaseVerificationID: String?
    private var pollingTask: Task<Void, Never>?

    var currentUser: AuthUser? {
        if case .authenticated(let user) = authState { return user }
        return nil
    }

    var isAuthenticated: Bool { currentUser != nil }

    var selectedRole: UserRole {
        let raw = UserDefaults.standard.string(forKey: "userRole") ?? UserRole.worker.rawValue
        return UserRole(rawValue: raw) ?? .worker
    }

    // MARK: - Onboarding Step (source of truth from backend state)

    var onboardingStep: OnboardingStep {
        guard let user = currentUser else { return .name }

        if !user.hasName { return .name }
        if !user.hasDOB { return .dob }
        if !user.hasAcceptedTerms { return .terms }
        if !user.hasAcceptedPrivacy { return .privacy }

        let role = selectedRole
        let hasProfile = role == .worker
            ? user.hasCompleteWorkerProfile
            : user.hasCompleteBusinessProfile

        if let status = profileStatus {
            let isRejected = role == .worker
                ? status.isWorkerRejected
                : status.isBusinessRejected
            if isRejected { return .profileDetails }
        }

        if !hasProfile { return .profileDetails }
        return .complete
    }

    var needsOnboarding: Bool { onboardingStep != .complete }
    var needsProfileDetails: Bool { onboardingStep == .profileDetails }

    // MARK: - Bootstrap

    func bootstrapIfNeeded() async {
        guard TokenStore.shared.accessToken != nil else {
            print("[AUTH] bootstrap: no access token, skipping")
            return
        }
        print("[AUTH] bootstrap: found access token, loading user...")
        await loadCurrentUser()
        if let user = currentUser {
            print("[AUTH] bootstrap: user loaded, id=\(user.id)")
            if let photo = user.profilePhoto {
                print("[AUTH] bootstrap: profilePhoto id=\(photo.id) status=\(photo.status) url256=\(photo.url256 ?? "nil") version=\(photo.version ?? "nil")")
                print("[AUTH] bootstrap: displayURL=\(photo.displayURL?.absoluteString ?? "nil")")
            } else {
                print("[AUTH] bootstrap: profilePhoto is nil")
            }
        } else {
            print("[AUTH] bootstrap: user is nil after loadCurrentUser")
        }
    }

    // MARK: - Send OTP

    func sendOTP(phone: String) async throws {
        isLoading = true
        defer { isLoading = false }
        clearError()

        do {
            let verificationID = try await PhoneAuthProvider.provider()
                .verifyPhoneNumber(phone, uiDelegate: nil)
            self.firebaseVerificationID = verificationID
            print("[AUTH] OTP sent successfully")
        } catch {
            let nsError = error as NSError
            print("[AUTH] sendOTP failed: domain=\(nsError.domain) code=\(nsError.code)")
            throw AppError.apiError(code: .unknown, message: error.localizedDescription)
        }
    }

    // MARK: - Verify OTP (Firebase flow)

    func verifyOTPWithFirebase(phone: String, otpCode: String) async throws {
        guard let verificationID = firebaseVerificationID else {
            throw AppError.apiError(code: .unknown, message: "No verification ID. Please resend the code.")
        }

        isLoading = true
        defer { isLoading = false }
        clearError()

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: otpCode
        )

        let authResult: AuthDataResult
        do {
            authResult = try await Auth.auth().signIn(with: credential)
            print("[AUTH] Firebase sign-in succeeded")
        } catch {
            throw AppError.apiError(code: .otpInvalid, message: "Invalid verification code. Please try again.")
        }

        guard let idToken = try? await authResult.user
            .getIDTokenResult(forcingRefresh: true).token else {
            throw AppError.apiError(code: .unknown, message: "Failed to get Firebase ID token.")
        }

        let verifiedPhone = authResult.user.phoneNumber ?? phone
        let profileType = selectedRole.rawValue

        let response: VerifyOTPResponse = try await APIClient.shared.publicRequest(
            .verifyOTPFirebase(phone: verifiedPhone, profileType: profileType, idToken: idToken)
        )
        storeTokens(response.tokens)
        authState = .authenticated(user: response.user)
        await loadProfileStatus()
    }

    // MARK: - Load Current User

    func loadCurrentUser() async {
        do {
            let response: MeResponse = try await APIClient.shared.request(.me)
            print("[AUTH] loadCurrentUser: got user id=\(response.user.id) photo=\(response.user.profilePhoto != nil ? "exists" : "nil")")
            if let photo = response.user.profilePhoto {
                print("[AUTH] loadCurrentUser: photo id=\(photo.id) status=\(photo.status) url256=\(photo.url256 ?? "nil")")
            }
            authState = .authenticated(user: response.user)
            await loadProfileStatus()
        } catch AppError.unauthorized {
            print("[AUTH] loadCurrentUser: unauthorized, signing out")
            signOut()
        } catch {
            print("[AUTH] loadCurrentUser failed: \(error)")
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
        await loadCurrentUser()
    }

    // MARK: - Name Update (Step 4)

    func updateName(firstName: String, lastName: String) async throws {
        isLoading = true
        defer { isLoading = false }
        clearError()
        let req = NameUpdateRequest(firstName: firstName, lastName: lastName)
        let _: NameUpdateResponse = try await APIClient.shared.request(.updateName(req))
        await loadCurrentUser()
    }

    // MARK: - DOB Update (Step 5)

    func updateDOB(dateOfBirth: String) async throws {
        isLoading = true
        defer { isLoading = false }
        clearError()
        let req = DOBUpdateRequest(dateOfBirth: dateOfBirth)
        let _: DOBUpdateResponse = try await APIClient.shared.request(.updateDOB(req))
        await loadCurrentUser()
    }

    // MARK: - Terms Accept (Step 6)

    /// Accept the terms using the version string returned by GET /api/v1/legal/terms/.
    /// The caller (TermsAcceptView) must fetch the live document first and pass its version here.
    func acceptTerms(version: String) async throws {
        isLoading = true
        defer { isLoading = false }
        clearError()
        let req = TermsAcceptRequest(accepted: true, termsVersion: version)
        let _: TermsAcceptResponse = try await APIClient.shared.request(.acceptTerms(req))
        await loadCurrentUser()
    }

    // MARK: - Privacy Policy Accept

    func acceptPrivacy(version: String) async throws {
        isLoading = true
        defer { isLoading = false }
        clearError()
        let req = PrivacyAcceptRequest(accepted: true, privacyVersion: version)
        let _: PrivacyAcceptResponse = try await APIClient.shared.request(.acceptPrivacy(req))
        await loadCurrentUser()
        print("[AUTH] acceptPrivacy: after reload, hasAcceptedPrivacy=\(currentUser?.hasAcceptedPrivacy ?? false) privacyAcceptedAt=\(currentUser?.privacyAcceptedAt ?? "nil")")
    }

    // MARK: - Account Deletion

    func deleteAccount(phone: String) async throws {
        isLoading = true
        defer { isLoading = false }
        clearError()
        let req = AccountDeleteRequest(phone: phone)
        let _: AccountDeleteResponse = try await APIClient.shared.request(.deleteAccount(req))
        signOut()
    }

    // MARK: - Profile Creation (Step 7)

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

    // MARK: - Profile Status + Access Tier

    func loadProfileStatus() async {
        do {
            let status: ProfileStatus = try await APIClient.shared.request(.profileStatus)
            profileStatus = status
        } catch {
            print("[AUTH] loadProfileStatus failed: \(error)")
        }
        do {
            let tier: AccessTier = try await APIClient.shared.request(.accessTier)
            accessTier = tier
        } catch {
            print("[AUTH] loadAccessTier failed: \(error)")
        }
    }

    // MARK: - Verification Polling

    func startVerificationPolling() {
        stopVerificationPolling()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                guard !Task.isCancelled else { return }
                await loadProfileStatus()
                await loadCurrentUser()
                if onboardingStep == .complete { return }
            }
        }
    }

    func stopVerificationPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Sign Out

    func signOut() {
        stopVerificationPolling()

        // Unregister FCM device before clearing tokens
        if let fcmToken = AppDelegate.currentFCMToken {
            Task.detached {
                await MessageStore.shared.unregisterDevice(token: fcmToken)
            }
        }

        // Best-effort backend logout (blacklist refresh token). No UX changes:
        // fire-and-forget; local token state is cleared immediately.
        Task.detached {
            await APIClient.shared.logout()
        }

        TokenStore.shared.clearAll()
        authState = .unauthenticated
        profileStatus = nil
        accessTier = nil
        clearError()
        // Clear all jobs/applications state
        JobStore.shared.clearAll()
        // Clear all messaging state
        MessageStore.shared.clearAll()
        // Clear review state
        ReviewStore.shared.clearAll()
        // Reset to role picker on next login
        UserDefaults.standard.removeObject(forKey: "hasPickedRole")
        UserDefaults.standard.removeObject(forKey: "userRole")
    }

    // MARK: - Helpers

    private func storeTokens(_ tokens: AuthTokenResponse) {
        TokenStore.shared.accessToken = tokens.access
        TokenStore.shared.refreshToken = tokens.refresh
    }

    func clearError() { error = nil }
    func setError(_ err: AppError) { error = err }

    /// Update user in-place (used by ProfilePhotoUploader after upload confirm)
    func updateUser(_ user: AuthUser) {
        authState = .authenticated(user: user)
    }
}

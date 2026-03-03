//
//  EmailVerificationView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct EmailVerificationView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var isSent = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var cooldownSeconds = 0
    @State private var cooldownTimer: Timer?
    @FocusState private var isEmailFocused: Bool

    // Deep-link / manual token entry
    @State private var manualToken = ""
    @State private var showManualEntry = false
    @State private var isVerifying = false

    private var isEmailValid: Bool {
        let emailRegex = /^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$/
        return (try? emailRegex.wholeMatch(in: email)) != nil
    }

    private var canSend: Bool {
        isEmailValid && !isLoading && cooldownSeconds == 0
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                    // Header
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Enter your email address")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.Colors.primaryText)

                        Text("Add your email to aid in account recovery")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding(.top, Theme.Spacing.xxl)

                    if !isSent {
                        // Email input
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Email")
                                .font(Theme.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.Colors.primaryText)

                            TextField("jon.mobbin2@gmail.com", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(Theme.Typography.body)
                                .focused($isEmailFocused, equals: true)
                                .padding(Theme.Spacing.lg)
                                .background(Theme.Colors.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                        .stroke(
                                            isEmailFocused ? Theme.Colors.inputBorderFocused : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                    } else {
                        // Sent confirmation
                        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                            Text("We sent a verification link to \(email)")
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.secondaryText)

                            if cooldownSeconds > 0 {
                                Text("Resend in \(cooldownSeconds)s")
                                    .font(Theme.Typography.footnote)
                                    .foregroundColor(Theme.Colors.secondaryText)
                            } else {
                                Button("Resend verification link") {
                                    Task { await resendVerification() }
                                }
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.accent)
                            }

                            Button("Change email address") {
                                withAnimation { isSent = false }
                            }
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.Colors.secondaryText)

                            // Refresh status
                            Button(action: { Task { await authStore.loadCurrentUser() } }) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("I've verified - refresh status")
                                }
                                .font(Theme.Typography.bodySemibold)
                                .foregroundColor(Theme.Colors.primaryText)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Theme.Colors.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                            }
                            .padding(.top, Theme.Spacing.sm)

                            // Manual token entry
                            Button(showManualEntry ? "Hide manual entry" : "Enter token manually") {
                                withAnimation { showManualEntry.toggle() }
                            }
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)

                            if showManualEntry {
                                TextField("Paste your verification token", text: $manualToken)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .font(Theme.Typography.footnote)
                                    .padding(Theme.Spacing.md)
                                    .background(Theme.Colors.inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))

                                Button(action: verifyToken) {
                                    if isVerifying {
                                        ProgressView().progressViewStyle(.circular).tint(.white)
                                            .frame(maxWidth: .infinity, minHeight: 40)
                                    } else {
                                        Text("Verify Token")
                                            .font(Theme.Typography.headlineSemibold)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 40)
                                            .background(manualToken.isEmpty ? Color.black.opacity(0.3) : Color.black)
                                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                                    }
                                }
                                .disabled(manualToken.isEmpty || isVerifying)
                            }
                        }
                    }

                    // Error / Success
                    if let error = errorMessage {
                        Text(error)
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.Colors.error)
                    }

                    if let success = successMessage {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.Colors.success)
                            Text(success)
                                .font(Theme.Typography.footnote)
                                .foregroundColor(Theme.Colors.success)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }

            // Bottom bar
            if !isSent {
                OnboardingBottomBar(
                    onBack: { dismiss() },
                    onNext: sendVerification,
                    isLoading: isLoading,
                    isEnabled: canSend
                )
            }
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
        .onOpenURL { handleDeepLink($0) }
    }

    // MARK: - Actions

    private func sendVerification() {
        guard canSend else { return }
        errorMessage = nil
        successMessage = nil
        isLoading = true

        Task {
            defer { isLoading = false }
            do {
                try await authStore.sendEmailVerification(email: email)
                withAnimation { isSent = true }
                startCooldown(seconds: 60)
            } catch AppError.apiError(let code, _) where code == .emailAlreadyVerified {
                successMessage = "This email is already verified."
                await authStore.loadCurrentUser()
            } catch AppError.rateLimited(let retryAfter) {
                let secs = Int(retryAfter ?? 60)
                startCooldown(seconds: secs)
                errorMessage = "Too many requests. Please wait \(secs) seconds."
            } catch let appError as AppError {
                errorMessage = appError.errorDescription
            } catch {
                errorMessage = AppError.network(underlying: error).errorDescription
            }
        }
    }

    private func resendVerification() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await authStore.sendEmailVerification(email: email)
            successMessage = "Verification link resent."
            startCooldown(seconds: 60)
        } catch AppError.rateLimited(let retryAfter) {
            let secs = Int(retryAfter ?? 60)
            startCooldown(seconds: secs)
            errorMessage = "Too many requests. Please wait \(secs) seconds."
        } catch let appError as AppError {
            errorMessage = appError.errorDescription
        } catch {
            errorMessage = AppError.network(underlying: error).errorDescription
        }
    }

    private func verifyToken() {
        guard !manualToken.isEmpty else { return }
        isVerifying = true
        errorMessage = nil

        Task {
            defer { isVerifying = false }
            do {
                try await authStore.verifyEmailToken(manualToken)
                successMessage = "Email verified successfully."
            } catch let appError as AppError {
                errorMessage = appError.errorDescription
            } catch {
                errorMessage = AppError.network(underlying: error).errorDescription
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value
        else { return }

        Task {
            do {
                try await authStore.verifyEmailToken(token)
                successMessage = "Email verified successfully."
            } catch let appError as AppError {
                errorMessage = appError.errorDescription
            } catch {
                errorMessage = AppError.network(underlying: error).errorDescription
            }
        }
    }

    private func startCooldown(seconds: Int) {
        cooldownSeconds = seconds
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                if cooldownSeconds > 0 { cooldownSeconds -= 1 }
                else { cooldownTimer?.invalidate() }
            }
        }
    }
}

#Preview {
    NavigationStack {
        EmailVerificationView()
            .environmentObject(AuthStore.shared)
    }
}

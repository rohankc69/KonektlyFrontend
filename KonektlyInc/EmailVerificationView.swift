//
//  EmailVerificationView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct EmailVerificationView: View {
    @EnvironmentObject private var authStore: AuthStore

    @State private var email: String = ""
    @State private var isSent = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var cooldownSeconds = 0
    @State private var cooldownTimer: Timer?

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
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.xxxl) {
                    headerSection

                    if !isSent {
                        emailInputSection
                        sendButton
                    } else {
                        sentConfirmationSection
                        manualTokenSection
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.huge)
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .navigationTitle("Verify Email")
        .navigationBarTitleDisplayMode(.inline)
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.accent.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: isSent ? "envelope.badge.checkmark.fill" : "envelope.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.accent)
            }

            Text(isSent ? "Check Your Inbox" : "Verify Your Email")
                .font(Theme.Typography.largeTitle)
                .foregroundColor(Theme.Colors.primaryText)

            Text(isSent
                 ? "We sent a verification link to\n\(email)"
                 : "Add and verify your email address to unlock full access")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var emailInputSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Email Address")
                .font(Theme.Typography.headlineSemibold)
                .foregroundColor(Theme.Colors.primaryText)

            TextField("you@example.com", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
                .padding(Theme.Spacing.lg)
                .background(Theme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(email.isEmpty ? Theme.Colors.border
                                : isEmailValid ? Theme.Colors.accent : Theme.Colors.error,
                                lineWidth: 1.5)
                )
                .cornerRadius(Theme.CornerRadius.medium)

            if let error = errorMessage {
                ErrorBanner(message: error) { errorMessage = nil }
            }

            if let success = successMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.Colors.success)
                    Text(success).font(Theme.Typography.footnote).foregroundColor(Theme.Colors.success)
                }
            }
        }
    }

    private var sendButton: some View {
        Button(action: sendVerification) {
            if isLoading {
                ProgressView().progressViewStyle(.circular).tint(.white)
                    .frame(maxWidth: .infinity, minHeight: Theme.Sizes.buttonHeight)
            } else {
                Text("Send Verification Link")
                    .primaryButtonStyle(isEnabled: canSend)
            }
        }
        .disabled(!canSend)
        .frame(height: Theme.Sizes.buttonHeight)
    }

    private var sentConfirmationSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Resend
            VStack(spacing: Theme.Spacing.sm) {
                if cooldownSeconds > 0 {
                    Text("Resend in \(cooldownSeconds)s")
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.secondaryText)
                } else {
                    Button("Resend verification link") {
                        Task { await resendVerification() }
                    }
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.accent)
                }

                Button("Change email address") {
                    withAnimation { isSent = false }
                }
                .font(Theme.Typography.footnote)
                .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(.top, Theme.Spacing.sm)

            if let error = errorMessage {
                ErrorBanner(message: error) { errorMessage = nil }
            }

            if let success = successMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.Colors.success)
                    Text(success).font(Theme.Typography.footnote).foregroundColor(Theme.Colors.success)
                }
            }

            // Refresh status button
            Button(action: { Task { await authStore.loadCurrentUser() } }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("I've verified - refresh status")
                }
                .font(Theme.Typography.bodySemibold)
                .foregroundColor(Theme.Colors.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Sizes.buttonHeight)
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )
            }
        }
    }

    private var manualTokenSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
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
                    .foregroundColor(Theme.Colors.primaryText)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )
                    .cornerRadius(Theme.CornerRadius.medium)

                Button(action: verifyToken) {
                    if isVerifying {
                        ProgressView().progressViewStyle(.circular).tint(.white)
                            .frame(maxWidth: .infinity, minHeight: Theme.Sizes.smallButtonHeight)
                    } else {
                        Text("Verify Token")
                            .font(Theme.Typography.headlineSemibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: Theme.Sizes.smallButtonHeight)
                            .background(manualToken.isEmpty ? Theme.Colors.primary.opacity(0.4) : Theme.Colors.primary)
                            .cornerRadius(Theme.CornerRadius.medium)
                    }
                }
                .disabled(manualToken.isEmpty || isVerifying)
            }
        }
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
                successMessage = "This email is already verified!"
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
            successMessage = "Verification link resent!"
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
                successMessage = "Email verified successfully!"
            } catch let appError as AppError {
                errorMessage = appError.errorDescription
            } catch {
                errorMessage = AppError.network(underlying: error).errorDescription
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Expected: konektly://verify-email?token=<token>
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value
        else { return }

        Task {
            do {
                try await authStore.verifyEmailToken(token)
                successMessage = "Email verified successfully!"
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

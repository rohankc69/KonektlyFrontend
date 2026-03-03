//
//  PhoneLoginView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct PhoneLoginView: View {
    @EnvironmentObject private var authStore: AuthStore

    @State private var phoneNumber = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var navigateToOTP = false
    @State private var cooldownSeconds = 0
    @State private var cooldownTimer: Timer?

    private var formattedPhone: String {
        // Strip whitespace/dashes; keep the + prefix
        let stripped = phoneNumber.filter { $0.isNumber || $0 == "+" }
        return stripped
    }

    private var isPhoneValid: Bool {
        let digits = formattedPhone.filter(\.isNumber)
        return digits.count >= 7 && digits.count <= 15
    }

    private var canSubmit: Bool {
        isPhoneValid && !isLoading && cooldownSeconds == 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.xxxl) {
                        headerSection
                        inputSection
                        Spacer(minLength: Theme.Spacing.xxl)
                        continueButton
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.huge)
                    .padding(.bottom, Theme.Spacing.xxl)
                }
            }
            .navigationDestination(isPresented: $navigateToOTP) {
                OTPVerificationView(phoneNumber: formattedPhone)
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("Sign In")
                .font(Theme.Typography.largeTitle)
                .foregroundColor(Theme.Colors.primaryText)

            Text("Enter your phone number to get started")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Phone Number")
                .font(Theme.Typography.headlineSemibold)
                .foregroundColor(Theme.Colors.primaryText)

            HStack(spacing: Theme.Spacing.sm) {
                // Country code hint
                Image(systemName: "globe")
                    .font(.system(size: 22))
                    .foregroundColor(Theme.Colors.secondaryText)

                TextField("+1 (555) 000-0000", text: $phoneNumber)
                    .keyboardType(.phonePad)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(phoneNumber.isEmpty ? Theme.Colors.border : Theme.Colors.accent, lineWidth: 1.5)
            )
            .cornerRadius(Theme.CornerRadius.medium)

            if let error = errorMessage {
                ErrorBanner(message: error) { errorMessage = nil }
            }

            Text("Include your country code, e.g. +1 for Canada/US")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }

    private var continueButton: some View {
        VStack(spacing: Theme.Spacing.md) {
            Button(action: sendOTP) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .frame(maxWidth: .infinity, minHeight: Theme.Sizes.buttonHeight)
                } else if cooldownSeconds > 0 {
                    Text("Resend in \(cooldownSeconds)s")
                        .primaryButtonStyle(isEnabled: false)
                } else {
                    Text("Send Code")
                        .primaryButtonStyle(isEnabled: canSubmit)
                }
            }
            .disabled(!canSubmit)
            .frame(height: Theme.Sizes.buttonHeight)
        }
    }

    // MARK: - Actions

    private func sendOTP() {
        guard canSubmit else { return }
        errorMessage = nil
        isLoading = true

        Task {
            defer { isLoading = false }
            do {
                try await authStore.sendOTP(phone: formattedPhone)
                navigateToOTP = true
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

    private func startCooldown(seconds: Int) {
        cooldownSeconds = seconds
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                if cooldownSeconds > 0 {
                    cooldownSeconds -= 1
                } else {
                    cooldownTimer?.invalidate()
                }
            }
        }
    }
}

// MARK: - Reusable Error Banner

struct ErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(Theme.Colors.error)

            Text(message)
                .font(Theme.Typography.footnote)
                .foregroundColor(Theme.Colors.error)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.error.opacity(0.08))
        .cornerRadius(Theme.CornerRadius.small)
    }
}

#Preview {
    PhoneLoginView()
        .environmentObject(AuthStore.shared)
}

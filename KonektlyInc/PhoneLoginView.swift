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
    @FocusState private var isPhoneFocused: Bool

    private var formattedPhone: String {
        phoneNumber.filter { $0.isNumber || $0 == "+" }
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
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                        // Header
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Enter your mobile number")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Theme.Colors.primaryText)
                        }
                        .padding(.top, Theme.Spacing.xxl)

                        // Phone input
                        HStack(spacing: Theme.Spacing.sm) {
                            // Country code hint
                            HStack(spacing: Theme.Spacing.xs) {
                                Image(systemName: "globe")
                                    .font(.system(size: 18))
                                    .foregroundColor(Theme.Colors.secondaryText)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .frame(height: 52)
                            .background(Theme.Colors.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))

                            // Phone field
                            TextField("+1 Mobile number", text: $phoneNumber)
                                .keyboardType(.phonePad)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.primaryText)
                                .focused($isPhoneFocused)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .padding(.horizontal, Theme.Spacing.lg)
                                .frame(height: 52)
                                .background(Theme.Colors.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                        .stroke(
                                            isPhoneFocused ? Theme.Colors.inputBorderFocused : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }

                        // Error
                        if let error = errorMessage {
                            Text(error)
                                .font(Theme.Typography.footnote)
                                .foregroundColor(Theme.Colors.error)
                        }

                        // Consent text
                        Text("By proceeding, you consent to get calls, SMS messages, including by automated dialer, from Konektly and its affiliates to the number provided.")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .padding(.top, Theme.Spacing.sm)
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }

                // Bottom bar
                HStack {
                    // Back button (go to role picker)
                    Button(action: {}) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Theme.Colors.primaryText)
                            .frame(width: 44, height: 44)
                            .background(Theme.Colors.cardBackground)
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Continue button
                    Button(action: sendOTP) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .frame(width: 100, height: 48)
                        } else {
                            Text("Continue")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, Theme.Spacing.xl)
                                .frame(height: 48)
                        }
                    }
                    .background(canSubmit ? Color.black : Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.pill))
                    .disabled(!canSubmit)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.lg)
            }
            .background(Theme.Colors.background)
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToOTP) {
                OTPVerificationView(phoneNumber: formattedPhone)
            }
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
                if cooldownSeconds > 0 { cooldownSeconds -= 1 }
                else { cooldownTimer?.invalidate() }
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

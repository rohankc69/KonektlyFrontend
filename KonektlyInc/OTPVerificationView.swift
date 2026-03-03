//
//  OTPVerificationView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct OTPVerificationView: View {
    let phoneNumber: String

    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss

    // 6-digit OTP boxes
    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedIndex: Int?

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cooldownSeconds = 0
    @State private var cooldownTimer: Timer?

    // Dev mode state - defaults to OFF so Firebase path is used
    @State private var isDevMode = false
    @State private var devCode = ""

    private var otpCode: String { otpDigits.joined() }
    private var isComplete: Bool { otpCode.count == 6 }
    private var canSubmit: Bool { isComplete && !isLoading }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.xxxl) {
                    headerSection
                    if isDevMode {
                        devFallbackSection
                    } else {
                        otpInputSection
                    }
                    submitButton
                    resendSection
                    if Config.isDevOTPFallbackEnabled {
                        devToggle
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.huge)
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .navigationTitle("Verify Phone")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focusedIndex = 0 }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("Enter Code")
                .font(Theme.Typography.largeTitle)
                .foregroundColor(Theme.Colors.primaryText)

            Group {
                Text("Sent to ")
                    .foregroundColor(Theme.Colors.secondaryText)
                + Text(phoneNumber)
                    .foregroundColor(Theme.Colors.primaryText)
                    .fontWeight(.medium)
            }
            .font(Theme.Typography.subheadline)
        }
    }

    private var otpInputSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(0..<6, id: \.self) { index in
                    OTPDigitBox(
                        digit: otpDigits[index],
                        isFocused: focusedIndex == index
                    )
                    .onTapGesture { focusedIndex = index }
                }
            }

            // Hidden text field capturing keyboard input
            TextField("", text: Binding(
                get: { otpCode },
                set: { handleOTPInput($0) }
            ))
            .keyboardType(.numberPad)
            .focused($focusedIndex, equals: 0)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)

            if let error = errorMessage {
                ErrorBanner(message: error) { errorMessage = nil }
            }
        }
    }

    private var devFallbackSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("Dev Mode - Plain Code", systemImage: "hammer.fill")
                .font(Theme.Typography.footnote)
                .foregroundColor(Theme.Colors.warning)

            TextField("Enter code from backend logs", text: $devCode)
                .keyboardType(.numberPad)
                .padding(Theme.Spacing.lg)
                .background(Theme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(Theme.Colors.warning, lineWidth: 1.5)
                )
                .cornerRadius(Theme.CornerRadius.medium)

            if let error = errorMessage {
                ErrorBanner(message: error) { errorMessage = nil }
            }
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .frame(maxWidth: .infinity, minHeight: Theme.Sizes.buttonHeight)
            } else {
                Text("Verify")
                    .primaryButtonStyle(isEnabled: isDevMode ? !devCode.isEmpty : canSubmit)
            }
        }
        .disabled(isDevMode ? devCode.isEmpty || isLoading : !canSubmit)
        .frame(height: Theme.Sizes.buttonHeight)
    }

    private var resendSection: some View {
        HStack {
            if cooldownSeconds > 0 {
                Text("Resend code in \(cooldownSeconds)s")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.secondaryText)
            } else {
                Button("Didn't receive a code? Resend") {
                    Task { await resendOTP() }
                }
                .font(Theme.Typography.footnote)
                .foregroundColor(Theme.Colors.accent)
            }
        }
    }

    private var devToggle: some View {
        Toggle(isOn: $isDevMode) {
            Label("Use dev code fallback", systemImage: "hammer")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .toggleStyle(.switch)
        .tint(Theme.Colors.warning)
        .padding(.top, Theme.Spacing.lg)
    }

    // MARK: - OTP Input Handling

    private func handleOTPInput(_ value: String) {
        let digits = value.filter(\.isNumber).prefix(6)
        for (i, char) in digits.enumerated() {
            otpDigits[i] = String(char)
        }
        for i in digits.count..<6 {
            otpDigits[i] = ""
        }
        if digits.count < 6 { focusedIndex = digits.count }
        if digits.count == 6 { focusedIndex = nil }
    }

    // MARK: - Actions

    private func submit() {
        errorMessage = nil
        isLoading = true

        Task {
            defer { isLoading = false }
            do {
                if isDevMode {
                    print("[OTP] Submitting via DEV fallback path, code length=\(devCode.count)")
                    try await authStore.verifyOTPDev(phone: phoneNumber, code: devCode)
                } else {
                    print("[OTP] Submitting via FIREBASE path, otp length=\(otpCode.count)")
                    try await authStore.verifyOTPWithFirebase(phone: phoneNumber, otpCode: otpCode)
                }
            } catch AppError.rateLimited(let retryAfter) {
                let secs = Int(retryAfter ?? 60)
                startCooldown(seconds: secs)
                errorMessage = "Too many attempts. Please wait \(secs) seconds."
            } catch AppError.serviceUnavailable(let msg) {
                errorMessage = msg
            } catch AppError.conflict(let msg) {
                errorMessage = msg
            } catch let appError as AppError {
                errorMessage = appError.errorDescription
                if case .apiError(let code, _) = appError, code == .otpInvalid || code == .invalidOTP {
                    otpDigits = Array(repeating: "", count: 6)
                    focusedIndex = 0
                }
            } catch {
                errorMessage = AppError.network(underlying: error).errorDescription
            }
        }
    }

    private func resendOTP() async {
        errorMessage = nil
        do {
            try await authStore.sendOTP(phone: phoneNumber)
            otpDigits = Array(repeating: "", count: 6)
            focusedIndex = 0
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

// MARK: - OTP Digit Box

struct OTPDigitBox: View {
    let digit: String
    let isFocused: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .fill(Theme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(isFocused ? Theme.Colors.accent : Theme.Colors.border,
                                lineWidth: isFocused ? 2 : 1)
                )
                .frame(width: 48, height: 56)
                .shadow(color: isFocused ? Theme.Colors.accent.opacity(0.2) : .clear,
                        radius: 6, x: 0, y: 2)

            Text(digit)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.Colors.primaryText)
        }
    }
}

#Preview {
    NavigationStack {
        OTPVerificationView(phoneNumber: "+1 555 000 0000")
            .environmentObject(AuthStore.shared)
    }
}

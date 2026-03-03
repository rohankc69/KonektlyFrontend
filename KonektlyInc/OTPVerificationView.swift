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

    @State private var otpDigits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedIndex: Int?

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var cooldownSeconds = 0
    @State private var cooldownTimer: Timer?

    @State private var isDevMode = false
    @State private var devCode = ""

    private var otpCode: String { otpDigits.joined() }
    private var isComplete: Bool { otpCode.count == 6 }
    private var canSubmit: Bool { isComplete && !isLoading }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                    // Header
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Enter the 6-digit code sent to you at \(phoneNumber).")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.Colors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, Theme.Spacing.xxl)

                    if isDevMode {
                        // Dev fallback input
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Dev code")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                            TextField("Enter code from backend logs", text: $devCode)
                                .keyboardType(.numberPad)
                                .font(Theme.Typography.body)
                                .padding(Theme.Spacing.lg)
                                .background(Theme.Colors.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                        .stroke(Theme.Colors.inputBorderFocused, lineWidth: 2)
                                )
                        }
                    } else {
                        // OTP digit boxes
                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach(0..<6, id: \.self) { index in
                                ZStack {
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                        .fill(Theme.Colors.inputBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                                .stroke(
                                                    focusedIndex == index ? Theme.Colors.inputBorderFocused : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                        .frame(height: 52)

                                    Text(otpDigits[index])
                                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                                        .foregroundColor(Theme.Colors.primaryText)
                                }
                                .onTapGesture { focusedIndex = 0 }
                            }
                        }

                        // Hidden text field
                        TextField("", text: Binding(
                            get: { otpCode },
                            set: { handleOTPInput($0) }
                        ))
                        .keyboardType(.numberPad)
                        .focused($focusedIndex, equals: 0)
                        .frame(width: 0, height: 0)
                        .opacity(0)
                        .accessibilityHidden(true)
                    }

                    // Error
                    if let error = errorMessage {
                        Text(error)
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.Colors.error)
                    }

                    // Resend link
                    if cooldownSeconds > 0 {
                        Text("I didn't receive a code (\(cooldownSeconds)s)")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    } else {
                        Button("I didn't receive a code") {
                            Task { await resendOTP() }
                        }
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    }

                    // Dev toggle
                    if Config.isDevOTPFallbackEnabled {
                        Toggle(isOn: $isDevMode) {
                            Text("Use dev code fallback")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                        .toggleStyle(.switch)
                        .tint(Theme.Colors.warning)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }

            // Bottom bar: back arrow + Next button
            bottomBar
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
        .onAppear { focusedIndex = 0 }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Theme.Colors.primaryText)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.cardBackground)
                    .clipShape(Circle())
            }

            Spacer()

            Button(action: submit) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .frame(width: 100, height: 48)
                } else {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text("Next")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .frame(height: 48)
                }
            }
            .background(nextButtonEnabled ? Color.black : Color.black.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.pill))
            .disabled(!nextButtonEnabled)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.lg)
    }

    private var nextButtonEnabled: Bool {
        isDevMode ? (!devCode.isEmpty && !isLoading) : (canSubmit)
    }

    // MARK: - OTP Input

    private func handleOTPInput(_ value: String) {
        let digits = value.filter(\.isNumber).prefix(6)
        for (i, char) in digits.enumerated() {
            otpDigits[i] = String(char)
        }
        for i in digits.count..<6 {
            otpDigits[i] = ""
        }
        if digits.count < 6 { focusedIndex = 0 }
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

#Preview {
    NavigationStack {
        OTPVerificationView(phoneNumber: "+1 555 000 0000")
            .environmentObject(AuthStore.shared)
    }
}

//
//  TermsAcceptView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-03.
//

import SwiftUI

struct TermsAcceptView: View {
    @EnvironmentObject private var authStore: AuthStore

    @State private var hasRead = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: Theme.Spacing.xxl) {
                        // Progress indicator
                        OnboardingProgress(currentStep: 3, totalSteps: 4)

                        headerSection
                        termsContent
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xxl)
                    .padding(.bottom, Theme.Spacing.lg)
                }

                // Fixed bottom section
                VStack(spacing: Theme.Spacing.md) {
                    if let error = errorMessage {
                        ErrorBanner(message: error) { errorMessage = nil }
                    }

                    agreementToggle
                    acceptButton
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.lg)
                .background(Theme.Colors.background)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: -4)
            }
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Sign Out") { authStore.signOut() }
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("Review our Terms")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.primaryText)
            Text("Please read and accept to continue.")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }

    private var termsContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            termsSection(
                title: "1. Account Usage",
                body: "You agree to provide accurate information during registration. Your account is personal and you are responsible for all activity under it."
            )

            termsSection(
                title: "2. Platform Rules",
                body: "Workers and businesses must conduct themselves professionally. Harassment, fraud, or misrepresentation will result in account suspension."
            )

            termsSection(
                title: "3. Verification",
                body: "You consent to identity verification through government-issued ID. Verification data is handled securely and used solely for trust and safety purposes."
            )

            termsSection(
                title: "4. Payments",
                body: "Konektly facilitates connections between workers and businesses. Payment terms are agreed upon between parties. Konektly may charge service fees."
            )

            termsSection(
                title: "5. Privacy",
                body: "Your personal data is collected and processed in accordance with our Privacy Policy. We do not sell your data to third parties."
            )

            termsSection(
                title: "6. Termination",
                body: "Konektly reserves the right to suspend or terminate accounts that violate these terms. You may delete your account at any time."
            )
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
    }

    private func termsSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Typography.headlineSemibold)
                .foregroundColor(Theme.Colors.primaryText)
            Text(body)
                .font(Theme.Typography.footnote)
                .foregroundColor(Theme.Colors.secondaryText)
                .lineSpacing(4)
        }
    }

    private var agreementToggle: some View {
        Button(action: { hasRead.toggle() }) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: hasRead ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(hasRead ? Theme.Colors.primary : Theme.Colors.border)

                Text("I have read and agree to the Terms of Service")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.primaryText)
                    .multilineTextAlignment(.leading)

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var acceptButton: some View {
        Button(action: accept) {
            if isLoading {
                ProgressView().progressViewStyle(.circular).tint(.white)
                    .frame(maxWidth: .infinity, minHeight: Theme.Sizes.buttonHeight)
            } else {
                Text("Accept and Continue")
                    .primaryButtonStyle(isEnabled: hasRead)
            }
        }
        .disabled(!hasRead || isLoading)
        .frame(height: Theme.Sizes.buttonHeight)
    }

    // MARK: - Actions

    private func accept() {
        guard hasRead else { return }
        isLoading = true
        errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                try await authStore.acceptTerms()
            } catch let appError as AppError {
                errorMessage = appError.errorDescription
            } catch {
                errorMessage = AppError.network(underlying: error).errorDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        TermsAcceptView()
            .environmentObject(AuthStore.shared)
    }
}

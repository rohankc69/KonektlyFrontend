//
//  TermsAcceptView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-03.
//

import SwiftUI

struct TermsAcceptView: View {
    @EnvironmentObject private var authStore: AuthStore

    @State private var hasAgreed = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                    // Header with icon
                    HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Theme.Colors.primaryText)

                        Text("Accept Konektly's Terms & Review Privacy Notice")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.Colors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, Theme.Spacing.xxl)

                    // Terms text
                    Text("By selecting \"I Agree\" below, I have reviewed and agree to the ")
                        .foregroundColor(Theme.Colors.secondaryText)
                    + Text("Terms of Use")
                        .foregroundColor(Theme.Colors.accent)
                    + Text(" and acknowledge the ")
                        .foregroundColor(Theme.Colors.secondaryText)
                    + Text("Privacy Notice")
                        .foregroundColor(Theme.Colors.accent)
                    + Text(". I am at least 18 years of age.")
                        .foregroundColor(Theme.Colors.secondaryText)

                    // Error
                    if let error = errorMessage {
                        Text(error)
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.Colors.error)
                    }
                }
                .font(Theme.Typography.subheadline)
                .padding(.horizontal, Theme.Spacing.xl)
            }

            // Bottom section: checkbox + bar
            VStack(spacing: Theme.Spacing.lg) {
                // I Agree checkbox
                Button(action: { hasAgreed.toggle() }) {
                    HStack {
                        Text("I Agree")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.primaryText)
                        Spacer()
                        Image(systemName: hasAgreed ? "checkmark.square.fill" : "square")
                            .font(.system(size: 24))
                            .foregroundColor(hasAgreed ? Theme.Colors.accent : Theme.Colors.border)
                    }
                }
                .buttonStyle(.plain)

                // Bottom bar
                OnboardingBottomBar(
                    onBack: { authStore.signOut() },
                    onNext: accept,
                    isLoading: isLoading,
                    isEnabled: hasAgreed
                )
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.sm)
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
    }

    private func accept() {
        guard hasAgreed else { return }
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

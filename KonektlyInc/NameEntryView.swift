//
//  NameEntryView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-03.
//

import SwiftUI

struct NameEntryView: View {
    @EnvironmentObject private var authStore: AuthStore

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isFirstNameValid: Bool {
        firstName.trimmingCharacters(in: .whitespaces).count >= 2
    }

    private var isLastNameValid: Bool {
        lastName.trimmingCharacters(in: .whitespaces).count >= 2
    }

    private var canSubmit: Bool {
        isFirstNameValid && isLastNameValid && !isLoading
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Progress indicator
                    OnboardingProgress(currentStep: 2, totalSteps: 4)

                    headerSection
                    formSection

                    if let error = errorMessage {
                        ErrorBanner(message: error) { errorMessage = nil }
                    }

                    submitButton

                    Spacer(minLength: Theme.Spacing.xxl)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xxl)
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .navigationTitle("Your Name")
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
            Text("What's your name?")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.primaryText)
            Text("This will be visible on your profile.")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("First Name")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)

                TextField("Jane", text: $firstName)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .autocorrectionDisabled()
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                            .stroke(borderColor(for: firstName, isValid: isFirstNameValid), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))

                if !firstName.isEmpty && !isFirstNameValid {
                    Text("At least 2 characters")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.error)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Last Name")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)

                TextField("Doe", text: $lastName)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .autocorrectionDisabled()
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                            .stroke(borderColor(for: lastName, isValid: isLastNameValid), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))

                if !lastName.isEmpty && !isLastNameValid {
                    Text("At least 2 characters")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.error)
                }
            }
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            if isLoading {
                ProgressView().progressViewStyle(.circular).tint(.white)
                    .frame(maxWidth: .infinity, minHeight: Theme.Sizes.buttonHeight)
            } else {
                Text("Continue")
                    .primaryButtonStyle(isEnabled: canSubmit)
            }
        }
        .disabled(!canSubmit)
        .frame(height: Theme.Sizes.buttonHeight)
    }

    // MARK: - Helpers

    private func borderColor(for text: String, isValid: Bool) -> Color {
        if text.isEmpty { return Theme.Colors.border }
        return isValid ? Theme.Colors.accent : Theme.Colors.error
    }

    private func submit() {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                try await authStore.updateName(
                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces)
                )
            } catch let appError as AppError {
                errorMessage = appError.errorDescription
            } catch {
                errorMessage = AppError.network(underlying: error).errorDescription
            }
        }
    }
}

// MARK: - Onboarding Progress Indicator (reusable)

struct OnboardingProgress: View {
    let currentStep: Int
    let totalSteps: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(1...totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Theme.Colors.primary : Theme.Colors.border)
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, Theme.Spacing.sm)
    }
}

#Preview {
    NavigationStack {
        NameEntryView()
            .environmentObject(AuthStore.shared)
    }
}

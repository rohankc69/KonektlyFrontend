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
    @FocusState private var focusedField: Field?

    private enum Field { case first, last }

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
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                    // Header
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("What's your name?")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.Colors.primaryText)

                        Text("Let us know how to properly address you")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding(.top, Theme.Spacing.xxl)

                    // Form fields
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // First name
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("First name")
                                .font(Theme.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.Colors.primaryText)

                            TextField("Enter first name", text: $firstName)
                                .font(Theme.Typography.body)
                                .focused($focusedField, equals: .first)
                                .autocorrectionDisabled()
                                .padding(Theme.Spacing.lg)
                                .background(Theme.Colors.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                        .stroke(
                                            focusedField == .first ? Theme.Colors.inputBorderFocused : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }

                        // Last name
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Last name")
                                .font(Theme.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.Colors.primaryText)

                            TextField("Enter last name", text: $lastName)
                                .font(Theme.Typography.body)
                                .focused($focusedField, equals: .last)
                                .autocorrectionDisabled()
                                .padding(Theme.Spacing.lg)
                                .background(Theme.Colors.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                        .stroke(
                                            focusedField == .last ? Theme.Colors.inputBorderFocused : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                    }

                    // Error
                    if let error = errorMessage {
                        Text(error)
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.Colors.error)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }

            // Bottom bar
            OnboardingBottomBar(
                onBack: { authStore.signOut() },
                onNext: submit,
                isLoading: isLoading,
                isEnabled: canSubmit
            )
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
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

// MARK: - Reusable Onboarding Bottom Bar

struct OnboardingBottomBar: View {
    let onBack: () -> Void
    let onNext: () -> Void
    var isLoading: Bool = false
    var isEnabled: Bool = true

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Theme.Colors.primaryText)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.cardBackground)
                    .clipShape(Circle())
            }

            Spacer()

            Button(action: onNext) {
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
            .background(isEnabled && !isLoading ? Theme.Colors.buttonPrimary : Theme.Colors.buttonPrimary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.pill))
            .disabled(!isEnabled || isLoading)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.lg)
    }
}

#Preview {
    NavigationStack {
        NameEntryView()
            .environmentObject(AuthStore.shared)
    }
}

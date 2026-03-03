//
//  ProfileCreateView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

// MARK: - Worker Profile Create View

struct WorkerProfileCreateView: View {
    @EnvironmentObject private var authStore: AuthStore

    @State private var govIdNumber = ""
    @State private var govIdType = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let govIdTypes = [
        "drivers_license", "passport", "national_id", "state_id"
    ]

    private let govIdTypeLabels: [String: String] = [
        "drivers_license": "Driver's License",
        "passport": "Passport",
        "national_id": "National ID",
        "state_id": "State ID"
    ]

    private var isValid: Bool {
        !govIdNumber.trimmingCharacters(in: .whitespaces).isEmpty && !govIdType.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                    // Header
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Verify your identity")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.Colors.primaryText)

                        Text("We need your government ID to get you verified")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding(.top, Theme.Spacing.xxl)

                    // Form
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // ID Type picker
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("ID Type")
                                .font(Theme.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.Colors.primaryText)

                            Menu {
                                ForEach(govIdTypes, id: \.self) { type in
                                    Button(govIdTypeLabels[type] ?? type) { govIdType = type }
                                }
                            } label: {
                                HStack {
                                    Text(govIdType.isEmpty ? "Select ID type" : (govIdTypeLabels[govIdType] ?? govIdType))
                                        .font(Theme.Typography.body)
                                        .foregroundColor(govIdType.isEmpty ? Theme.Colors.secondaryText : Theme.Colors.primaryText)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(Theme.Colors.secondaryText)
                                        .font(.system(size: 12))
                                }
                                .padding(Theme.Spacing.lg)
                                .background(Theme.Colors.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                            }
                        }

                        // ID Number
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("ID Number")
                                .font(Theme.Typography.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.Colors.primaryText)

                            TextField("Enter your ID number", text: $govIdNumber)
                                .font(Theme.Typography.body)
                                .autocorrectionDisabled()
                                .padding(Theme.Spacing.lg)
                                .background(Theme.Colors.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
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
                isEnabled: isValid
            )
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
    }

    private func submit() {
        guard isValid else { return }
        isLoading = true
        errorMessage = nil

        let req = WorkerProfileCreateRequest(
            govIdNumber: govIdNumber.trimmingCharacters(in: .whitespaces),
            govIdType: govIdType
        )

        Task {
            defer { isLoading = false }
            do {
                try await authStore.createWorkerProfile(req)
            } catch AppError.conflict(let msg) {
                errorMessage = msg
            } catch let appError as AppError {
                errorMessage = appError.errorDescription
            } catch {
                errorMessage = AppError.network(underlying: error).errorDescription
            }
        }
    }
}

// MARK: - Business Profile Create View

struct BusinessProfileCreateView: View {
    @EnvironmentObject private var authStore: AuthStore

    @State private var businessId = ""
    @State private var businessName = ""
    @State private var managerGovIdNumber = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !businessId.trimmingCharacters(in: .whitespaces).isEmpty &&
        !businessName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !managerGovIdNumber.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                    // Header
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Business verification")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.Colors.primaryText)

                        Text("Provide your business info to get verified")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding(.top, Theme.Spacing.xxl)

                    // Form
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        OnboardingTextField(label: "Business Name", placeholder: "Acme Corp", text: $businessName)
                        OnboardingTextField(label: "Business ID", placeholder: "e.g. BN123456789", text: $businessId)
                        OnboardingTextField(label: "Manager Gov ID", placeholder: "Manager ID number", text: $managerGovIdNumber)
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
                isEnabled: isValid
            )
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
    }

    private func submit() {
        guard isValid else { return }
        isLoading = true
        errorMessage = nil

        let req = BusinessProfileCreateRequest(
            businessId: businessId.trimmingCharacters(in: .whitespaces),
            businessName: businessName.trimmingCharacters(in: .whitespaces),
            managerGovIdNumber: managerGovIdNumber.trimmingCharacters(in: .whitespaces)
        )

        Task {
            defer { isLoading = false }
            do {
                try await authStore.createBusinessProfile(req)
            } catch AppError.conflict(let msg) {
                errorMessage = msg
            } catch let appError as AppError {
                errorMessage = appError.errorDescription
            } catch {
                errorMessage = AppError.network(underlying: error).errorDescription
            }
        }
    }
}

// MARK: - Reusable Onboarding Text Field

struct OnboardingTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(Theme.Typography.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Theme.Colors.primaryText)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(Theme.Typography.body)
                .focused($isFocused)
                .autocorrectionDisabled()
                .padding(Theme.Spacing.lg)
                .background(Theme.Colors.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        .stroke(
                            isFocused ? Theme.Colors.inputBorderFocused : Color.clear,
                            lineWidth: 2
                        )
                )
        }
    }
}

// MARK: - Legacy ProfileTextField (for backward compat)

struct ProfileTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        OnboardingTextField(label: label, placeholder: placeholder, text: $text, keyboardType: keyboardType)
    }
}

#Preview("Worker") {
    NavigationStack {
        WorkerProfileCreateView()
            .environmentObject(AuthStore.shared)
    }
}

#Preview("Business") {
    NavigationStack {
        BusinessProfileCreateView()
            .environmentObject(AuthStore.shared)
    }
}

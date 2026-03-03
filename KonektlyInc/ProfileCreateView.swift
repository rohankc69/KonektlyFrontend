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
        !govIdNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        !govIdType.isEmpty
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Progress indicator
                    OnboardingProgress(currentStep: 4, totalSteps: 4)

                    headerSection
                    formSection

                    if let error = errorMessage {
                        ErrorBanner(message: error) { errorMessage = nil }
                    }

                    submitButton
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xxl)
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .navigationTitle("Your Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Sign Out") { authStore.signOut() }
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("Verify Your Identity")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.primaryText)
            Text("We need your government ID to get you verified.")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("ID Type")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)

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
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                }
            }

            ProfileTextField(label: "ID Number", placeholder: "Enter your ID number", text: $govIdNumber)
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            if isLoading {
                ProgressView().progressViewStyle(.circular).tint(.white)
                    .frame(maxWidth: .infinity, minHeight: Theme.Sizes.buttonHeight)
            } else {
                Text("Continue")
                    .primaryButtonStyle(isEnabled: isValid)
            }
        }
        .disabled(!isValid || isLoading)
        .frame(height: Theme.Sizes.buttonHeight)
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
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Progress indicator
                    OnboardingProgress(currentStep: 4, totalSteps: 4)

                    headerSection
                    formSection

                    if let error = errorMessage {
                        ErrorBanner(message: error) { errorMessage = nil }
                    }

                    submitButton
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xxl)
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .navigationTitle("Business Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Sign Out") { authStore.signOut() }
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("Business Verification")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.primaryText)
            Text("Provide your business info to get verified.")
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            ProfileTextField(label: "Business Name", placeholder: "Acme Corp", text: $businessName)
            ProfileTextField(label: "Business ID", placeholder: "e.g. BN123456789", text: $businessId)
            ProfileTextField(label: "Manager Gov ID", placeholder: "Manager ID number", text: $managerGovIdNumber)
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            if isLoading {
                ProgressView().progressViewStyle(.circular).tint(.white)
                    .frame(maxWidth: .infinity, minHeight: Theme.Sizes.buttonHeight)
            } else {
                Text("Continue")
                    .primaryButtonStyle(isEnabled: isValid)
            }
        }
        .disabled(!isValid || isLoading)
        .frame(height: Theme.Sizes.buttonHeight)
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

// MARK: - Reusable Profile Text Field

struct ProfileTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
                .autocorrectionDisabled()
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
        }
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

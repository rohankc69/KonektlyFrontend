//
//  WorkerProfileCreateView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct WorkerProfileCreateView: View {
    @EnvironmentObject private var authStore: AuthStore

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var bio = ""
    @State private var skillInput = ""
    @State private var skills: [String] = []
    @State private var hourlyRate: Double = 18.0
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        hourlyRate >= 1
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.xxxl) {
                    headerSection
                    formSection
                    skillsSection
                    rateSection

                    if let error = errorMessage {
                        ErrorBanner(message: error) { errorMessage = nil }
                            .padding(.horizontal)
                    }

                    submitButton
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .navigationTitle("Worker Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.accent.opacity(0.12))
                    .frame(width: 90, height: 90)
                Image(systemName: "person.badge.plus.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Theme.Colors.accent)
            }
            Text("Build Your Profile")
                .font(Theme.Typography.title1)
                .foregroundColor(Theme.Colors.primaryText)
            Text("Help businesses find and hire you")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            ProfileTextField(label: "First Name", placeholder: "Jane", text: $firstName)
            ProfileTextField(label: "Last Name", placeholder: "Doe", text: $lastName)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Bio")
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.primaryText)

                ZStack(alignment: .topLeading) {
                    if bio.isEmpty {
                        Text("Tell businesses about yourself…")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.secondaryText.opacity(0.7))
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                    }
                    TextEditor(text: $bio)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )
                .cornerRadius(Theme.CornerRadius.medium)
            }
        }
    }

    private var skillsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Skills")
                .font(Theme.Typography.headlineSemibold)
                .foregroundColor(Theme.Colors.primaryText)

            HStack {
                TextField("e.g. Barista, Forklift, Excel", text: $skillInput)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .submitLabel(.done)
                    .onSubmit { addSkill() }

                Button(action: addSkill) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(skillInput.isEmpty ? Theme.Colors.border : Theme.Colors.accent)
                }
                .disabled(skillInput.isEmpty)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.border, lineWidth: 1)
            )
            .cornerRadius(Theme.CornerRadius.medium)

            if !skills.isEmpty {
                FlowLayout(spacing: Theme.Spacing.sm) {
                    ForEach(skills, id: \.self) { skill in
                        SkillChip(skill: skill) { removeSkill(skill) }
                    }
                }
            }
        }
    }

    private var rateSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Hourly Rate")
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
                Text(String(format: "$%.0f/hr", hourlyRate))
                    .font(Theme.Typography.headlineBold)
                    .foregroundColor(Theme.Colors.accent)
            }

            Slider(value: $hourlyRate, in: 15...100, step: 1)
                .tint(Theme.Colors.accent)

            HStack {
                Text("$15").font(Theme.Typography.caption).foregroundColor(Theme.Colors.secondaryText)
                Spacer()
                Text("$100").font(Theme.Typography.caption).foregroundColor(Theme.Colors.secondaryText)
            }
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            if isLoading {
                ProgressView().progressViewStyle(.circular).tint(.white)
                    .frame(maxWidth: .infinity, minHeight: Theme.Sizes.buttonHeight)
            } else {
                Text("Create Profile")
                    .primaryButtonStyle(isEnabled: isValid)
            }
        }
        .disabled(!isValid || isLoading)
        .frame(height: Theme.Sizes.buttonHeight)
    }

    // MARK: - Actions

    private func addSkill() {
        let trimmed = skillInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !skills.contains(trimmed) else { return }
        skills.append(trimmed)
        skillInput = ""
    }

    private func removeSkill(_ skill: String) {
        skills.removeAll { $0 == skill }
    }

    private func submit() {
        guard isValid else { return }
        isLoading = true
        errorMessage = nil

        let req = WorkerProfileCreateRequest(
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            bio: bio.trimmingCharacters(in: .whitespaces),
            skills: skills,
            hourlyRate: hourlyRate,
            availableFrom: nil
        )

        Task {
            defer { isLoading = false }
            do {
                try await authStore.createWorkerProfile(req)
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

    @State private var businessName = ""
    @State private var industry = ""
    @State private var description = ""
    @State private var website = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !businessName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !industry.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private let industries = [
        "Hospitality", "Retail", "Warehousing", "Construction",
        "Healthcare", "Food & Beverage", "Events", "Logistics", "Other"
    ]

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Theme.Spacing.xxxl) {
                    headerSection
                    formSection

                    if let error = errorMessage {
                        ErrorBanner(message: error) { errorMessage = nil }
                            .padding(.horizontal)
                    }

                    submitButton
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .navigationTitle("Business Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.accent.opacity(0.12))
                    .frame(width: 90, height: 90)
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Theme.Colors.accent)
            }
            Text("Set Up Your Business")
                .font(Theme.Typography.title1)
                .foregroundColor(Theme.Colors.primaryText)
            Text("Let workers find and apply to your shifts")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            ProfileTextField(label: "Business Name", placeholder: "Acme Corp", text: $businessName)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Industry")
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.primaryText)

                Menu {
                    ForEach(industries, id: \.self) { ind in
                        Button(ind) { industry = ind }
                    }
                } label: {
                    HStack {
                        Text(industry.isEmpty ? "Select industry" : industry)
                            .font(Theme.Typography.body)
                            .foregroundColor(industry.isEmpty ? Theme.Colors.secondaryText : Theme.Colors.primaryText)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundColor(Theme.Colors.secondaryText)
                            .font(.system(size: 12))
                    }
                    .padding(Theme.Spacing.lg)
                    .background(Theme.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .stroke(Theme.Colors.border, lineWidth: 1)
                    )
                    .cornerRadius(Theme.CornerRadius.medium)
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Description")
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.primaryText)

                ZStack(alignment: .topLeading) {
                    if description.isEmpty {
                        Text("Describe your business…")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.secondaryText.opacity(0.7))
                            .padding(.horizontal, 4)
                            .padding(.top, 8)
                    }
                    TextEditor(text: $description)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(Theme.Colors.border, lineWidth: 1)
                )
                .cornerRadius(Theme.CornerRadius.medium)
            }

            ProfileTextField(label: "Website (optional)", placeholder: "https://acmecorp.com", text: $website)
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            if isLoading {
                ProgressView().progressViewStyle(.circular).tint(.white)
                    .frame(maxWidth: .infinity, minHeight: Theme.Sizes.buttonHeight)
            } else {
                Text("Create Profile")
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
            businessName: businessName.trimmingCharacters(in: .whitespaces),
            industry: industry,
            description: description.trimmingCharacters(in: .whitespaces),
            website: website.isEmpty ? nil : website
        )

        Task {
            defer { isLoading = false }
            do {
                try await authStore.createBusinessProfile(req)
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
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(label)
                .font(Theme.Typography.headlineSemibold)
                .foregroundColor(Theme.Colors.primaryText)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.primaryText)
                .autocorrectionDisabled()
                .padding(Theme.Spacing.lg)
                .background(Theme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(text.isEmpty ? Theme.Colors.border : Theme.Colors.accent, lineWidth: 1.5)
                )
                .cornerRadius(Theme.CornerRadius.medium)
        }
    }
}

// MARK: - Skill Chip

struct SkillChip: View {
    let skill: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(skill)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.primaryText)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.Colors.chipBackground)
        .cornerRadius(Theme.CornerRadius.pill)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.pill)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
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

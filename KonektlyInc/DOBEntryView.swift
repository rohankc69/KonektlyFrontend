//
//  DOBEntryView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-03.
//

import SwiftUI

struct DOBEntryView: View {
    @EnvironmentObject private var authStore: AuthStore

    @State private var selectedDate = Calendar.current.date(
        byAdding: .year, value: -18, to: Date()
    ) ?? Date()
    @State private var hasPickedDate = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let minimumAge = 14

    private var maxDate: Date {
        Calendar.current.date(
            byAdding: .year, value: -minimumAge, to: Date()
        ) ?? Date()
    }

    private var minDate: Date {
        Calendar.current.date(
            byAdding: .year, value: -120, to: Date()
        ) ?? Date()
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: selectedDate)
    }

    // Format for backend: YYYY-MM-DD
    private var apiDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }

    private var isDateValid: Bool {
        selectedDate <= maxDate && selectedDate >= minDate
    }

    private var canSubmit: Bool {
        hasPickedDate && isDateValid && !isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                    // Header
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("When's your birthday?")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.Colors.primaryText)

                        Text("You must be at least \(minimumAge) years old to use Konektly")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .padding(.top, Theme.Spacing.xxl)

                    // Date display field
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Date of birth")
                            .font(Theme.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.primaryText)

                        HStack {
                            Text(hasPickedDate ? formattedDate : "Select your date of birth")
                                .font(Theme.Typography.body)
                                .foregroundColor(
                                    hasPickedDate
                                        ? Theme.Colors.primaryText
                                        : Theme.Colors.secondaryText
                                )
                            Spacer()
                            Image(systemName: "calendar")
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                        .padding(Theme.Spacing.lg)
                        .background(Theme.Colors.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                                .stroke(
                                    hasPickedDate ? Theme.Colors.inputBorderFocused : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }

                    // Inline date picker
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        in: minDate...maxDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .onChange(of: selectedDate) { _, _ in
                        hasPickedDate = true
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

    // MARK: - Actions

    private func submit() {
        guard canSubmit else { return }
        isLoading = true
        errorMessage = nil

        Task {
            defer { isLoading = false }
            do {
                try await authStore.updateDOB(dateOfBirth: apiDate)
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
        DOBEntryView()
            .environmentObject(AuthStore.shared)
    }
}

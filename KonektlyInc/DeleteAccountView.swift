//
//  DeleteAccountView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-25.
//

import SwiftUI

struct DeleteAccountView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var step: DeleteStep = .info
    @State private var confirmPhone = ""
    @State private var isDeleting = false
    @State private var errorMessage: String?
    @FocusState private var isPhoneFocused: Bool

    private enum DeleteStep {
        case info
        case confirm
    }

    private var userPhone: String {
        authStore.currentUser?.phone ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.Colors.primaryText)
                        .frame(width: 40, height: 40)
                        .background(Theme.Colors.inputBackground)
                        .clipShape(Circle())
                }

                Spacer()

                Text("Delete Account")
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.primaryText)

                Spacer()

                Color.clear
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    if step == .info {
                        infoSection
                    } else {
                        confirmSection
                    }
                }
                .padding(Theme.Spacing.xl)
            }

            // Bottom action
            VStack(spacing: Theme.Spacing.md) {
                if step == .info {
                    Button {
                        withAnimation { step = .confirm }
                    } label: {
                        Text("Continue")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.Colors.buttonPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    }
                } else {
                    Button(action: deleteAccount) {
                        if isDeleting {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else {
                            Text("Permanently Delete Account")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                    }
                    .background(confirmPhone.isEmpty || isDeleting ? Theme.Colors.buttonPrimary.opacity(0.3) : Theme.Colors.buttonPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    .disabled(confirmPhone.isEmpty || isDeleting)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
    }

    // MARK: - Info Step

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(Theme.Colors.error)
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.lg)

            Text("Are you sure you want to delete your account?")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.Colors.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                InfoRow(icon: "clock.fill", text: "Your account will be permanently deleted after 30 days.")
                InfoRow(icon: "arrow.uturn.backward", text: "You can cancel by logging in again within the 30-day period.")
                InfoRow(icon: "trash.fill", text: "After 30 days, all your data will be permanently removed and cannot be recovered.")
                InfoRow(icon: "briefcase.fill", text: "Active shifts and pending payments must be resolved first.")
            }
        }
    }

    // MARK: - Confirm Step

    private var confirmSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text("Confirm your identity")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.Colors.primaryText)

            Text("Enter your phone number to confirm account deletion.")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Phone Number")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)

                TextField(userPhone, text: $confirmPhone)
                    .keyboardType(.phonePad)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                    .focused($isPhoneFocused)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .frame(height: 52)
                    .background(Theme.Colors.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                            .stroke(
                                isPhoneFocused ? Theme.Colors.error : Color.clear,
                                lineWidth: 2
                            )
                    )
            }

            if let error = errorMessage {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(Theme.Colors.error)
                    Text(error)
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.error)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.error.opacity(0.08))
                .cornerRadius(Theme.CornerRadius.small)
            }
        }
        .onAppear { isPhoneFocused = true }
    }

    // MARK: - Actions

    private func deleteAccount() {
        guard !confirmPhone.isEmpty else { return }
        isDeleting = true
        errorMessage = nil

        Task {
            defer { isDeleting = false }
            do {
                try await authStore.deleteAccount(phone: confirmPhone)
                // signOut is called inside deleteAccount, view will be dismissed by navigation change
            } catch let appError as AppError {
                errorMessage = appError.errorDescription
            } catch {
                errorMessage = AppError.network(underlying: error).errorDescription
            }
        }
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.secondaryText)
                .frame(width: 24)
                .padding(.top, 2)

            Text(text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    DeleteAccountView()
        .environmentObject(AuthStore.shared)
}

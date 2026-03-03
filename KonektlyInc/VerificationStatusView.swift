//
//  VerificationStatusView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct VerificationStatusView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var isRefreshing = false

    private var user: AuthUser? { authStore.currentUser }
    private var status: ProfileStatus? { authStore.profileStatus }
    private var tier: AccessTier? { authStore.accessTier }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                if authStore.isLoading && status == nil {
                    ProgressView("Loading status...")
                        .progressViewStyle(.circular)
                } else {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.xl) {
                            accountHeader
                            accessTierCard
                            profileStatusCard
                            verificationChecklist
                            signOutButton
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.xl)
                    }
                    .refreshable { await refresh() }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { Task { await refresh() } }) {
                        if isRefreshing {
                            ProgressView().progressViewStyle(.circular)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing)
                }
            }
        }
        .task { await refresh() }
    }

    // MARK: - Subviews

    private var accountHeader: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if let phone = user?.phone {
                Text(phone)
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.primaryText)
            }

            if let email = user?.email, !email.isEmpty {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(email)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    if user?.emailVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Theme.Colors.accent)
                            .font(.system(size: 12))
                    }
                }
            }

            let role = authStore.selectedRole
            Text(role == .worker ? "Worker" : "Business")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Colors.tertiaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var accessTierCard: some View {
        if let tier {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Label("Access Tier", systemImage: "bolt.shield.fill")
                        .font(Theme.Typography.headlineBold)
                        .foregroundColor(Theme.Colors.primaryText)
                    Spacer()
                    Text(tier.accessTier.replacingOccurrences(of: "_", with: " ").uppercased())
                        .font(Theme.Typography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(tierColor(tier.accessTier))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.pill))
                }
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
            .shadow(color: Theme.Shadows.small.color, radius: Theme.Shadows.small.radius,
                    x: Theme.Shadows.small.x, y: Theme.Shadows.small.y)
        }
    }

    @ViewBuilder
    private var profileStatusCard: some View {
        if let status {
            let role = authStore.selectedRole
            let profileStatus = role == .worker ? status.workerStatus : status.businessStatus
            let isActive = status.isActiveProfile

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Label("Profile Status", systemImage: "person.crop.circle.badge.checkmark")
                        .font(Theme.Typography.headlineBold)
                        .foregroundColor(Theme.Colors.primaryText)
                    Spacer()
                    if let profileStatus {
                        HStack(spacing: Theme.Spacing.xs) {
                            Circle()
                                .fill(profileStatusColor(profileStatus))
                                .frame(width: 8, height: 8)
                            Text(profileStatus.capitalized)
                                .font(Theme.Typography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(profileStatusColor(profileStatus))
                        }
                    }
                }

                if isActive {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Theme.Colors.success)
                        Text("Your profile is active. You have full access to the platform.")
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                } else if profileStatus?.lowercased() == "pending" {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        Text("Your profile is being reviewed. You'll be notified once approved.")
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                } else if profileStatus?.lowercased() == "rejected" {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.error)
                        Text("Your profile was rejected. Please update your details and resubmit.")
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
            .shadow(color: Theme.Shadows.small.color, radius: Theme.Shadows.small.radius,
                    x: Theme.Shadows.small.x, y: Theme.Shadows.small.y)
        }
    }

    private var verificationChecklist: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Verification Checklist")
                .font(Theme.Typography.headlineBold)
                .foregroundColor(Theme.Colors.primaryText)

            VStack(spacing: Theme.Spacing.sm) {
                ChecklistRow(
                    title: "Phone Verified",
                    subtitle: "Required to sign in",
                    isComplete: user?.phone != nil,
                    isRequired: true
                )

                let role = authStore.selectedRole
                let hasProfile = role == .worker
                    ? (status?.hasWorkerProfile ?? user?.hasWorkerProfile ?? false)
                    : (status?.hasBusinessProfile ?? user?.hasBusinessProfile ?? false)

                ChecklistRow(
                    title: role == .worker ? "Worker Profile" : "Business Profile",
                    subtitle: role == .worker ? "Government ID submitted" : "Business details submitted",
                    isComplete: hasProfile,
                    isRequired: true
                )

                ChecklistRow(
                    title: "Profile Approved",
                    subtitle: "Verified by platform",
                    isComplete: status?.isActiveProfile ?? user?.isActiveProfile ?? false,
                    isRequired: true
                )
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
        .shadow(color: Theme.Shadows.small.color, radius: Theme.Shadows.small.radius,
                x: Theme.Shadows.small.x, y: Theme.Shadows.small.y)
    }

    private var signOutButton: some View {
        Button(action: { authStore.signOut() }) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign Out")
            }
            .font(Theme.Typography.bodySemibold)
            .foregroundColor(Theme.Colors.error)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Sizes.buttonHeight)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.error.opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Actions

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await authStore.loadProfileStatus()
        await authStore.loadCurrentUser()
    }

    private func tierColor(_ tier: String) -> Color {
        switch tier.lowercased() {
        case "fully_verified", "premium", "pro": return Color.purple
        case "identity_verified", "verified": return Color.blue
        case "phone_verified", "basic": return Theme.Colors.accent
        default: return Color.gray
        }
    }

    private func profileStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "approved": return Theme.Colors.success
        case "rejected": return Theme.Colors.error
        case "pending": return .orange
        default: return .gray
        }
    }
}

// MARK: - Supporting Views

struct ChecklistRow: View {
    let title: String
    let subtitle: String
    let isComplete: Bool
    let isRequired: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundColor(isComplete ? Theme.Colors.success : Theme.Colors.border)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                    if isRequired && !isComplete {
                        Text("Required")
                            .font(Theme.Typography.caption2)
                            .foregroundColor(Theme.Colors.error)
                    }
                }
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }

            Spacer()
        }
        .padding(.vertical, Theme.Spacing.sm)
    }
}

#Preview {
    VerificationStatusView()
        .environmentObject(AuthStore.shared)
}

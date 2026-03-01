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
                    ProgressView("Loading status…")
                        .progressViewStyle(.circular)
                } else {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.xl) {
                            accountHeader
                            accessTierCard
                            verificationChecklist
                            actionCards
                            refreshButton
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.xl)
                    }
                    .refreshable { await refresh() }
                }
            }
            .navigationTitle("Account Status")
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
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.Colors.accent, Theme.Colors.accent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "person.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.white)
            }

            if let phone = user?.phone {
                Text(phone)
                    .font(Theme.Typography.headlineBold)
                    .foregroundColor(Theme.Colors.primaryText)
            }

            if let email = user?.email {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(email)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                    if user?.emailVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                    }
                }
            }

            let role = UserRole(rawValue: user?.role ?? "") ?? .worker
            Text(role == .worker ? "Worker Account" : "Business Account")
                .font(Theme.Typography.caption)
                .foregroundColor(.white)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Colors.accent)
                .cornerRadius(Theme.CornerRadius.pill)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.large)
        .shadow(color: Theme.Shadows.small.color, radius: Theme.Shadows.small.radius,
                x: Theme.Shadows.small.x, y: Theme.Shadows.small.y)
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
                    Text(tier.tier.uppercased())
                        .font(Theme.Typography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(tierColor(tier.tier))
                        .cornerRadius(Theme.CornerRadius.pill)
                }

                Divider()

                HStack(spacing: Theme.Spacing.xl) {
                    TierFeatureRow(icon: "briefcase.fill",
                                  label: "Post Jobs",
                                  enabled: tier.canPostJobs)
                    TierFeatureRow(icon: "person.fill.checkmark",
                                  label: "Apply Jobs",
                                  enabled: tier.canApplyJobs)
                    if let max = tier.maxActiveJobs {
                        TierFeatureRow(icon: "list.number",
                                      label: "Max \(max) active",
                                      enabled: true)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.large)
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
                    isComplete: status?.phoneVerified ?? true,
                    isRequired: true
                )
                ChecklistRow(
                    title: "Email Verified",
                    subtitle: "Unlock messaging & notifications",
                    isComplete: user?.emailVerified ?? (status?.emailVerified ?? false),
                    isRequired: false
                )

                let role = UserRole(rawValue: user?.role ?? "") ?? .worker
                if role == .worker {
                    ChecklistRow(
                        title: "Worker Profile",
                        subtitle: "Required to apply for shifts",
                        isComplete: status?.hasWorkerProfile ?? user?.hasWorkerProfile ?? false,
                        isRequired: true
                    )
                    ChecklistRow(
                        title: "Identity Verified",
                        subtitle: "Unlock premium shifts",
                        isComplete: status?.identityVerified ?? false,
                        isRequired: false
                    )
                } else {
                    ChecklistRow(
                        title: "Business Profile",
                        subtitle: "Required to post shifts",
                        isComplete: status?.hasBusinessProfile ?? user?.hasBusinessProfile ?? false,
                        isRequired: true
                    )
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.large)
        .shadow(color: Theme.Shadows.small.color, radius: Theme.Shadows.small.radius,
                x: Theme.Shadows.small.x, y: Theme.Shadows.small.y)
    }

    @ViewBuilder
    private var actionCards: some View {
        let role = UserRole(rawValue: user?.role ?? "") ?? .worker
        let emailVerified = user?.emailVerified ?? (status?.emailVerified ?? false)
        let hasProfile = role == .worker
            ? (status?.hasWorkerProfile ?? user?.hasWorkerProfile ?? false)
            : (status?.hasBusinessProfile ?? user?.hasBusinessProfile ?? false)

        VStack(spacing: Theme.Spacing.md) {
            if !emailVerified {
                NavigationLink {
                    EmailVerificationView()
                        .environmentObject(authStore)
                } label: {
                    ActionCard(
                        icon: "envelope.badge.fill",
                        title: "Verify Your Email",
                        subtitle: "Tap to add & verify your email address",
                        isUrgent: true
                    )
                }
                .buttonStyle(.plain)
            }

            if !hasProfile {
                NavigationLink {
                    if role == .worker {
                        WorkerProfileCreateView().environmentObject(authStore)
                    } else {
                        BusinessProfileCreateView().environmentObject(authStore)
                    }
                } label: {
                    ActionCard(
                        icon: role == .worker ? "person.badge.plus.fill" : "briefcase.badge.plus.fill",
                        title: role == .worker ? "Complete Worker Profile" : "Complete Business Profile",
                        subtitle: "Required to start using the platform",
                        isUrgent: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var refreshButton: some View {
        Button(action: { Task { await refresh() } }) {
            HStack {
                if isRefreshing {
                    ProgressView().progressViewStyle(.circular).tint(Theme.Colors.primaryText)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
                Text("Refresh Status")
            }
            .font(Theme.Typography.bodySemibold)
            .foregroundColor(Theme.Colors.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Sizes.smallButtonHeight)
        }
        .disabled(isRefreshing)
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
        case "premium", "pro": return Color.purple
        case "verified": return Color.blue
        case "basic": return Theme.Colors.accent
        default: return Color.gray
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
            ZStack {
                Circle()
                    .fill(isComplete ? Theme.Colors.success.opacity(0.15) : Theme.Colors.border.opacity(0.3))
                    .frame(width: 36, height: 36)

                Image(systemName: isComplete ? "checkmark" : "clock")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isComplete ? Theme.Colors.success : Theme.Colors.secondaryText)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.primaryText)
                    if isRequired && !isComplete {
                        Text("Required")
                            .font(Theme.Typography.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.error)
                            .cornerRadius(4)
                    }
                }
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }

            Spacer()

            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.Colors.success)
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            isComplete
            ? Theme.Colors.success.opacity(0.05)
            : Theme.Colors.background
        )
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(isComplete ? Theme.Colors.success.opacity(0.3) : Theme.Colors.border,
                        lineWidth: 1)
        )
    }
}

struct ActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var isUrgent: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .fill(isUrgent ? Theme.Colors.accent.opacity(0.12) : Theme.Colors.chipBackground)
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isUrgent ? Theme.Colors.accent : Theme.Colors.primaryText)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Typography.headlineBold)
                    .foregroundColor(Theme.Colors.primaryText)
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                .stroke(isUrgent ? Theme.Colors.accent.opacity(0.4) : Theme.Colors.border, lineWidth: 1)
        )
        .shadow(color: Theme.Shadows.small.color, radius: Theme.Shadows.small.radius,
                x: Theme.Shadows.small.x, y: Theme.Shadows.small.y)
    }
}

struct TierFeatureRow: View {
    let icon: String
    let label: String
    let enabled: Bool

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(enabled ? Theme.Colors.accent : Theme.Colors.border)
            Text(label)
                .font(Theme.Typography.caption2)
                .foregroundColor(enabled ? Theme.Colors.primaryText : Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    VerificationStatusView()
        .environmentObject(AuthStore.shared)
}

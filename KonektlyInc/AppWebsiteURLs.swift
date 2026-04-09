//
//  AppWebsiteURLs.swift
//  KonektlyInc
//
//  Public web URLs for App Store compliance (privacy policy, support) and in-app Safari links.
//  Also declared in Info.plist for easy copy into App Store Connect metadata.
//

import Foundation
import SwiftUI

enum AppWebsiteURLs {
    /// Public privacy policy (matches App Store Connect “Privacy Policy URL”).
    static let privacyPolicy = URL(string: "https://konektly.ca/privacy-policy")!

    /// Marketing / help & support page (use for App Store “Support URL” where applicable).
    static let support = URL(string: "https://konektly.ca/support")!

    /// Terms of Use link shown on the subscription paywall (App Review requirement for auto-renewables).
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

// MARK: - In-app Safari affordances

/// Opens the canonical privacy policy on konektly.ca (App Review–visible alternative to API-fetched text).
struct PrivacyPolicySafariLinkCard: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(AppWebsiteURLs.privacyPolicy)
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "safari")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.Colors.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Official privacy policy")
                        .font(Theme.Typography.subheadline.weight(.semibold))
                        .foregroundColor(Theme.Colors.primaryText)
                    Text("konektly.ca/privacy-policy")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right.circle.fill")
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the privacy policy in Safari")
    }
}

/// Opens the public Help & Support page (App Store “Support URL” companion).
struct SupportWebsiteLinkCard: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(AppWebsiteURLs.support)
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "globe")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Theme.Colors.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Help & support website")
                        .font(Theme.Typography.subheadline.weight(.semibold))
                        .foregroundColor(Theme.Colors.primaryText)
                    Text("konektly.ca/support")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right.circle.fill")
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the support website in Safari")
    }
}

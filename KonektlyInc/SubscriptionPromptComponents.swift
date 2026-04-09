//
//  SubscriptionPromptComponents.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

// MARK: - Active Subscription Management Card
/// Shows for subscribed users - lets them manage/cancel subscription
struct ActiveSubscriptionCard: View {
    let onManage: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(Theme.Colors.success)
                            .font(.system(size: 20))
                        Text("Konektly+ Active")
                            .font(Theme.Typography.title2)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    
                    Text("You have access to all premium features")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                FeatureBullet(text: "Exact job locations")
                FeatureBullet(text: "Priority support")
                FeatureBullet(text: "Advanced analytics")
                FeatureBullet(text: "Early access to new features")
            }
            
            Button(action: onManage) {
                HStack {
                    Text("Manage Subscription")
                        .font(Theme.Typography.headlineSemibold)
                    Image(systemName: "gearshape")
                }
                .foregroundColor(Theme.Colors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(Theme.Colors.accent, lineWidth: 1.5)
                )
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            LinearGradient(
                colors: [
                    Theme.Colors.success.opacity(0.14),
                    Theme.Colors.success.opacity(0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                .stroke(
                    LinearGradient(
                        colors: [Theme.Colors.success.opacity(0.35), Theme.Colors.success.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Theme.Shadows.medium.color, radius: Theme.Shadows.medium.radius, x: 0, y: Theme.Shadows.medium.y)
    }
}

// MARK: - Large Upgrade Card (Featured)
/// Prominent upgrade card for profile - main conversion point
struct UpgradeCard: View {
    let onUpgrade: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 20))
                        Text("Konektly+")
                            .font(Theme.Typography.title2)
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                    
                    Text("Unlock premium features")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                FeatureBullet(text: "Exact job locations")
                FeatureBullet(text: "Priority support")
                FeatureBullet(text: "Advanced analytics")
                FeatureBullet(text: "Early access to new features")
            }
            
            Button(action: onUpgrade) {
                HStack {
                    Text("Upgrade Now")
                        .font(Theme.Typography.headlineSemibold)
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.md)
                .background(
                    LinearGradient(
                        colors: [Theme.Colors.accent, Theme.Colors.accent.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            LinearGradient(
                colors: [
                    Theme.Colors.accent.opacity(0.1),
                    Theme.Colors.accent.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                .stroke(
                    LinearGradient(
                        colors: [Theme.Colors.accent.opacity(0.3), Theme.Colors.accent.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Theme.Shadows.medium.color, radius: Theme.Shadows.medium.radius, x: 0, y: Theme.Shadows.medium.y)
    }
}

struct FeatureBullet: View {
    let text: String
    
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Theme.Colors.accent)
                .font(.system(size: 16))
            Text(text)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.primaryText)
        }
    }
}

// MARK: - Subtle Inline Upgrade Banner
/// A non-intrusive banner that can be placed in lists or scrollviews
/// Shows in profile for both workers and businesses
struct SubscriptionInlineBanner: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Theme.Colors.accent,
                                    Theme.Colors.accent.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upgrade to Konektly+")
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    Text("Get premium features and priority support")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(Theme.Spacing.lg)
            .background(
                LinearGradient(
                    colors: [
                        Theme.Colors.accent.opacity(0.08),
                        Theme.Colors.accent.opacity(0.04)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.accent.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Contextual Location Blur Prompt
/// Shows when job location is approximate/blurred
/// Only shown on individual job cards where it makes sense
struct LocationBlurPrompt: View {
    let onUpgrade: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.secondaryText)
                
                Text("Approximate location")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                
                Spacer()
                
                Button(action: onUpgrade) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 10))
                        Text("Unlock")
                            .font(Theme.Typography.caption.weight(.semibold))
                    }
                    .foregroundColor(Theme.Colors.accent)
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 6)
            .background(Theme.Colors.accent.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
        }
    }
}

// MARK: - Active Subscription Badge
/// Small badge to show on profile when subscribed
struct ActiveSubscriptionBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
            Text("Konektly+")
                .font(Theme.Typography.caption.weight(.semibold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 4)
        .background(
            LinearGradient(
                colors: [Theme.Colors.accent, Theme.Colors.accent.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
    }
}

#Preview("Active Subscription Card") {
    VStack(spacing: Theme.Spacing.lg) {
        ActiveSubscriptionCard(onManage: {})
            .padding()
    }
    .background(Theme.Colors.background)
}

#Preview("Upgrade Card") {
    VStack(spacing: Theme.Spacing.lg) {
        UpgradeCard(onUpgrade: {})
            .padding()
    }
    .background(Theme.Colors.background)
}

#Preview("Inline Banner") {
    VStack(spacing: Theme.Spacing.lg) {
        SubscriptionInlineBanner(onTap: {})
            .padding()
    }
    .background(Theme.Colors.background)
}

#Preview("Location Blur") {
    VStack(spacing: Theme.Spacing.lg) {
        LocationBlurPrompt(onUpgrade: {})
            .padding()
    }
    .background(Theme.Colors.background)
}

#Preview("Active Badge") {
    VStack(spacing: Theme.Spacing.lg) {
        ActiveSubscriptionBadge()
            .padding()
    }
    .background(Theme.Colors.background)
}

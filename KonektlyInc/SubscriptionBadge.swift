//
//  SubscriptionBadge.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI
import Combine

/// Small badge to show Konektly+ status
/// Use in profile headers, settings, etc.
struct SubscriptionBadge: View {
    @StateObject private var manager = SubscriptionManager.shared
    
    var body: some View {
        if manager.isKonektlyPlus {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                Text("Konektly+")
                    .font(Theme.Typography.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
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
}

/// Larger promotional badge for settings/profile
struct SubscriptionPromoBadge: View {
    @StateObject private var manager = SubscriptionManager.shared
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.Colors.accent, Theme.Colors.accent.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    if manager.isKonektlyPlus {
                        Text("Konektly+ Active")
                            .font(Theme.Typography.headlineSemibold)
                            .foregroundStyle(Theme.Colors.primaryText)
                        
                        Text("Tap to manage")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    } else {
                        Text("Upgrade to Konektly+")
                            .font(Theme.Typography.headlineSemibold)
                            .foregroundStyle(Theme.Colors.primaryText)
                        
                        Text("Unlock exact job locations")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: Theme.Sizes.iconSmall))
                    .foregroundStyle(Theme.Colors.tertiaryText)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(
                        manager.isKonektlyPlus
                            ? Theme.Colors.success.opacity(0.3)
                            : Theme.Colors.border,
                        lineWidth: 1
                    )
            )
        }
    }
}

#Preview("Badge - Plus User") {
    VStack {
        SubscriptionBadge()
    }
    .padding()
}

#Preview("Promo Badge - Free User") {
    SubscriptionPromoBadge(onTap: {})
        .padding()
}

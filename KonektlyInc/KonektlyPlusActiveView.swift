//
//  KonektlyPlusActiveView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct KonektlyPlusActiveView: View {
    let expiresAt: Date?
    let status: String
    let onManage: () -> Void
    
    private var expiryText: String {
        guard let date = expiresAt else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private var isCancelled: Bool {
        status == "cancelled"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                // Header
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.Colors.success)
                    
                    Text("Konektly+")
                        .font(Theme.Typography.largeTitle)
                        .foregroundStyle(Theme.Colors.primaryText)
                    
                    if isCancelled {
                        Text("Access until \(expiryText)")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    } else {
                        Text("Active Subscription")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
                .padding(.top, Theme.Spacing.xxl)
                
                // Status card
                VStack(spacing: Theme.Spacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Plan")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                            
                            Text("Konektly+ Monthly")
                                .font(Theme.Typography.headlineSemibold)
                                .foregroundStyle(Theme.Colors.primaryText)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: Theme.Sizes.iconLarge))
                            .foregroundStyle(Theme.Colors.accent)
                    }
                    
                    Divider()
                        .background(Theme.Colors.divider)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(isCancelled ? "Expires" : "Renews")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                            
                            Text(expiryText)
                                .font(Theme.Typography.bodySemibold)
                                .foregroundStyle(Theme.Colors.primaryText)
                        }
                        
                        Spacer()
                    }
                }
                .padding(Theme.Spacing.lg)
                .background(Theme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                .padding(.horizontal, Theme.Spacing.lg)
                
                // Active features
                VStack(spacing: Theme.Spacing.lg) {
                    Text("Active Features")
                        .font(Theme.Typography.title3)
                        .foregroundStyle(Theme.Colors.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    ActiveFeatureRow(
                        icon: "mappin.and.ellipse",
                        title: "Exact Job Locations"
                    )
                    
                    ActiveFeatureRow(
                        icon: "map.fill",
                        title: "Accurate Distance"
                    )
                    
                    ActiveFeatureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Better Planning"
                    )
                }
                .padding(.horizontal, Theme.Spacing.lg)
                
                Spacer()
                
                // Manage button
                Button("Manage Subscription", action: onManage)
                    .secondaryButtonStyle()
                    .padding(.horizontal, Theme.Spacing.lg)
                
                Text("Manage your subscription in App Store settings")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.lg)
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
    }
}

// MARK: - Active Feature Row

struct ActiveFeatureRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: Theme.Sizes.iconMedium))
                .foregroundStyle(Theme.Colors.success)
                .frame(width: 24)
            
            Text(title)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.primaryText)
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.Colors.success)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
    }
}

#Preview("Active") {
    KonektlyPlusActiveView(
        expiresAt: Calendar.current.date(byAdding: .month, value: 1, to: Date()),
        status: "active",
        onManage: {}
    )
}

#Preview("Cancelled") {
    KonektlyPlusActiveView(
        expiresAt: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
        status: "cancelled",
        onManage: {}
    )
}

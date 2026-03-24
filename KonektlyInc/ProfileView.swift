//
//  ProfileView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct ProfileView: View {
    @AppStorage("userRole") private var userRoleRaw: String = UserRole.worker.rawValue
    @State private var isAvailable = true
    @State private var showSettings = false
    @State private var showTerms = false
    @State private var showSubscription = false
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    
    private var userRole: UserRole {
        UserRole(rawValue: userRoleRaw) ?? .worker
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                    // Profile Header
                    VStack(spacing: Theme.Spacing.lg) {
                        // Avatar
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.Colors.primary, Theme.Colors.primary.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: Theme.Sizes.avatarExtraLarge, height: Theme.Sizes.avatarExtraLarge)
                            
                            HStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 56))
                                    .foregroundColor(.white)
                                
                                // Active subscription badge
                                if subscriptionManager.isKonektlyPlus {
                                    ActiveSubscriptionBadge()
                                        .offset(y: 20)
                                }
                            }
                            
                            // Verified badge
                            if MockData.currentUser.isVerified {
                                ZStack {
                                    Circle()
                                        .fill(Color(UIColor.systemBackground))
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.blue)
                                }
                                .offset(x: 5, y: 5)
                            }
                            
                            // Edit button
                            Button(action: {}) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(Theme.Colors.accent)
                                    .background(Circle().fill(Color(UIColor.systemBackground)).padding(-4))
                            }
                            .offset(x: -5, y: -5)
                        }
                        
                        // Name and role
                        VStack(spacing: Theme.Spacing.xs) {
                            Text(MockData.currentUser.name)
                                .font(Theme.Typography.title1)
                                .foregroundColor(Theme.Colors.primaryText)
                            
                            Text(userRole == .worker ? "Worker" : "Business Owner")
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                        
                        // Rating and stats
                        HStack(spacing: Theme.Spacing.xl) {
                            StatView(
                                icon: "star.fill",
                                value: String(format: "%.1f", MockData.currentUser.rating),
                                label: "Rating",
                                color: .yellow
                            )
                            
                            StatView(
                                icon: "checkmark.circle.fill",
                                value: "\(MockData.currentUser.completedShifts)",
                                label: "Completed",
                                color: Theme.Colors.accent
                            )
                            
                            if let hourlyRate = MockData.currentUser.hourlyRate {
                                StatView(
                                    icon: "dollarsign.circle.fill",
                                    value: "$\(Int(hourlyRate))",
                                    label: "Per Hour",
                                    color: .blue
                                )
                            }
                        }
                    }
                    .padding(.top, Theme.Spacing.lg)
                    
                    // SUBSCRIPTION CARD - Shows for EVERYONE (manage or upgrade)
                    if subscriptionManager.isKonektlyPlus {
                        // Active subscription - show management card
                        ActiveSubscriptionCard {
                            showSubscription = true
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                    } else {
                        // Not subscribed - show upgrade card
                        UpgradeCard {
                            showSubscription = true
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                    }
                    
                    // Availability Toggle (for workers)
                    if userRole == .worker {
                        VStack(spacing: Theme.Spacing.md) {
                            Toggle(isOn: $isAvailable) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    Circle()
                                        .fill(isAvailable ? Theme.Colors.success : Color.gray)
                                        .frame(width: 12, height: 12)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Available for Work")
                                            .font(Theme.Typography.headlineSemibold)
                                            .foregroundColor(Theme.Colors.primaryText)
                                        
                                        Text(isAvailable ? "You're visible to businesses" : "You won't receive job offers")
                                            .font(Theme.Typography.caption)
                                            .foregroundColor(Theme.Colors.secondaryText)
                                    }
                                }
                            }
                            .tint(Theme.Colors.accent)
                        }
                        .padding(Theme.Spacing.lg)
                        .cardStyle()
                        .padding(.horizontal, Theme.Spacing.lg)
                        .onChange(of: isAvailable) { _, _ in
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }
                    }
                    
                    // Bio Section
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("About")
                            .font(Theme.Typography.title3)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        Text(MockData.currentUser.bio)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.lg)
                    .cardStyle()
                    .padding(.horizontal, Theme.Spacing.lg)
                    
                    // Skills Section
                    if !MockData.currentUser.skills.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("Skills")
                                .font(Theme.Typography.title3)
                                .foregroundColor(Theme.Colors.primaryText)
                            
                            FlowLayout(spacing: Theme.Spacing.sm) {
                                ForEach(MockData.currentUser.skills, id: \.self) { skill in
                                    Text(skill)
                                        .font(Theme.Typography.subheadline.weight(.medium))
                                        .foregroundColor(Theme.Colors.accent)
                                        .padding(.horizontal, Theme.Spacing.md)
                                        .padding(.vertical, Theme.Spacing.sm)
                                        .background(Theme.Colors.accent.opacity(0.1))
                                        .cornerRadius(Theme.CornerRadius.pill)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.CornerRadius.pill)
                                                .stroke(Theme.Colors.accent.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.lg)
                        .cardStyle()
                        .padding(.horizontal, Theme.Spacing.lg)
                    }
                    
                    // Settings List
                    VStack(spacing: 0) {
                        SettingsRow(icon: "person.fill", title: "Edit Profile", showChevron: true) {}
                        Divider().padding(.leading, 52)
                        
                        // Subscription row - AVAILABLE FOR ALL USERS
                        SettingsRow(
                            icon: "star.circle.fill",
                            title: subscriptionManager.isKonektlyPlus ? "Konektly+ Active" : "Upgrade to Konektly+",
                            showChevron: true
                        ) {
                            showSubscription = true
                        }
                        Divider().padding(.leading, 52)
                        
                        SettingsRow(icon: "bell.fill", title: "Notifications", showChevron: true) {}
                        Divider().padding(.leading, 52)
                        
                        SettingsRow(icon: "creditcard.fill", title: "Payment Methods", showChevron: true) {}
                        Divider().padding(.leading, 52)
                        
                        SettingsRow(icon: "doc.text.fill", title: "Work History", showChevron: true) {}
                        Divider().padding(.leading, 52)
                        
                        SettingsRow(icon: "questionmark.circle.fill", title: "Help & Support", showChevron: true) {}
                        Divider().padding(.leading, 52)

                        SettingsRow(icon: "doc.text.fill", title: "Terms & Conditions", showChevron: true) {
                            showTerms = true
                        }
                        Divider().padding(.leading, 52)

                        SettingsRow(icon: "gearshape.fill", title: "Settings", showChevron: true) {}
                    }
                    .cardStyle()
                    .padding(.horizontal, Theme.Spacing.lg)
                    
                    // Logout button
                    Button(action: logout) {
                        Text("Log Out")
                            .font(Theme.Typography.headlineSemibold)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .frame(height: Theme.Sizes.buttonHeight)
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.CornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
                            )
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                }
            }
            .navigationDestination(isPresented: $showTerms) {
                TermsReadView()
            }
            .sheet(isPresented: $showSubscription) {
                NavigationStack {
                    SubscriptionView()
                        .navigationTitle("Konektly+")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showSubscription = false
                                }
                            }
                        }
                }
            }
    }

    private func logout() {
        // Reset onboarding state
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Stat View

struct StatView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: Theme.Sizes.iconLarge))
                .foregroundColor(color)
            
            Text(value)
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.primaryText)
            
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String
    let showChevron: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: Theme.Sizes.iconMedium))
                    .foregroundColor(Theme.Colors.primaryText)
                    .frame(width: 28)
                
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: Theme.Sizes.iconSmall))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            .padding(Theme.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    ProfileView()
}

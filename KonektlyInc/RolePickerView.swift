//
//  RolePickerView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct RolePickerView: View {
    @AppStorage("userRole") private var userRoleRaw: String = ""
    @Binding var hasCompletedOnboarding: Bool
    
    @State private var selectedRole: UserRole?
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background
            Theme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: Theme.Spacing.xxxl) {
                // Header
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Theme.Colors.accent)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.0)
                    
                    Text("Welcome to Konektly")
                        .font(Theme.Typography.largeTitle)
                        .foregroundColor(Theme.Colors.primaryText)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(y: isAnimating ? 0 : 20)
                    
                    Text("Connect with opportunities\nor find the perfect hire")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .opacity(isAnimating ? 1.0 : 0.0)
                        .offset(y: isAnimating ? 0 : 20)
                }
                .padding(.top, Theme.Spacing.huge)
                
                // Role Selection Cards
                VStack(spacing: Theme.Spacing.lg) {
                    RoleCard(
                        icon: "briefcase.fill",
                        title: "I'm a Business",
                        subtitle: "Post jobs and hire workers",
                        role: .business,
                        isSelected: selectedRole == .business
                    ) {
                        withAnimation(Theme.Animation.smooth) {
                            selectedRole = .business
                        }
                    }
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .offset(x: isAnimating ? 0 : -50)
                    
                    RoleCard(
                        icon: "person.fill",
                        title: "I'm a Worker",
                        subtitle: "Find shifts and earn money",
                        role: .worker,
                        isSelected: selectedRole == .worker
                    ) {
                        withAnimation(Theme.Animation.smooth) {
                            selectedRole = .worker
                        }
                    }
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .offset(x: isAnimating ? 0 : 50)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                
                Spacer()
                
                // Continue Button
                Button(action: completeOnboarding) {
                    Text("Continue")
                        .primaryButtonStyle(isEnabled: selectedRole != nil)
                }
                .disabled(selectedRole == nil)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xxl)
                .opacity(isAnimating ? 1.0 : 0.0)
            }
        }
        .onAppear {
            withAnimation(Theme.Animation.smooth.delay(0.2)) {
                isAnimating = true
            }
        }
    }
    
    private func completeOnboarding() {
        guard let role = selectedRole else { return }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        userRoleRaw = role.rawValue
        
        withAnimation(Theme.Animation.smooth) {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Role Card Component

struct RoleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let role: UserRole
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.Colors.accent : Theme.Colors.tertiaryBackground)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(isSelected ? .white : Theme.Colors.primaryText)
                }
                
                // Text
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(Theme.Typography.headlineBold)
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    Text(subtitle)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                
                Spacer()
                
                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.Colors.accent)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .stroke(
                        isSelected ? Theme.Colors.accent : Theme.Colors.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .cornerRadius(Theme.CornerRadius.large)
            .shadow(
                color: isSelected ? Theme.Shadows.medium.color : Theme.Shadows.small.color,
                radius: isSelected ? Theme.Shadows.medium.radius : Theme.Shadows.small.radius,
                x: 0,
                y: isSelected ? Theme.Shadows.medium.y : Theme.Shadows.small.y
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RolePickerView(hasCompletedOnboarding: .constant(false))
}

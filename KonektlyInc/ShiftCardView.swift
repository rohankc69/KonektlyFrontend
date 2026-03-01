//
//  ShiftCardView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct ShiftCardView: View {
    let shift: Shift
    let userRole: UserRole
    let onPrimaryAction: () -> Void
    let onSecondaryAction: (() -> Void)?
    
    init(shift: Shift, userRole: UserRole, onPrimaryAction: @escaping () -> Void, onSecondaryAction: (() -> Void)? = nil) {
        self.shift = shift
        self.userRole = userRole
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header: Business name and rating
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(shift.businessName)
                        .font(Theme.Typography.headlineBold)
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "star.fill")
                            .font(.system(size: Theme.Sizes.iconSmall))
                            .foregroundColor(.yellow)
                        
                        Text(String(format: "%.1f", shift.businessRating))
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
                
                Spacer()
                
                if shift.isUrgent {
                    Text("URGENT")
                        .font(Theme.Typography.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Theme.Colors.urgent)
                        .cornerRadius(Theme.CornerRadius.small)
                }
            }
            
            // Job title
            Text(shift.jobTitle)
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.primaryText)
            
            // Description
            Text(shift.description)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .lineLimit(2)
            
            // Skills required
            if !shift.requiredSkills.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(shift.requiredSkills, id: \.self) { skill in
                            Text(skill)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.primaryText)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(Theme.Colors.tertiaryBackground)
                                .cornerRadius(Theme.CornerRadius.pill)
                        }
                    }
                }
            }
            
            Divider()
            
            // Time and rate info
            HStack(spacing: Theme.Spacing.lg) {
                // Time
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: Theme.Sizes.iconSmall))
                        .foregroundColor(Theme.Colors.tertiaryText)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shift.timeString)
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        Text(shift.duration)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
                
                Spacer()
                
                // Rate
                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(Int(shift.hourlyRate))/hr")
                        .font(Theme.Typography.headlineBold)
                        .foregroundColor(Theme.Colors.accent)
                    
                    Text("Est. $\(Int(shift.hourlyRate * Double((Calendar.current.dateComponents([.hour], from: shift.startTime, to: shift.endTime).hour ?? 0))))")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            
            // Location
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "location.fill")
                    .font(.system(size: Theme.Sizes.iconSmall))
                    .foregroundColor(Theme.Colors.secondaryText)
                
                Text(shift.location.address)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primaryText)
                    .lineLimit(1)
            }
            
            // Action buttons
            HStack(spacing: Theme.Spacing.md) {
                if let secondaryAction = onSecondaryAction {
                    Button(action: secondaryAction) {
                        Text(userRole == .worker ? "Decline" : "View Details")
                            .secondaryButtonStyle()
                    }
                }
                
                Button(action: onPrimaryAction) {
                    Text(userRole == .worker ? "Accept Shift" : "Hire")
                        .primaryButtonStyle()
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .cardStyle()
    }
}

#Preview {
    VStack {
        ShiftCardView(
            shift: MockData.shifts[0],
            userRole: .worker,
            onPrimaryAction: {},
            onSecondaryAction: {}
        )
        .padding()
        
        ShiftCardView(
            shift: MockData.shifts[1],
            userRole: .business,
            onPrimaryAction: {}
        )
        .padding()
    }
}

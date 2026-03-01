//
//  WorkerCardView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct WorkerCardView: View {
    let worker: Worker
    let onPrimaryAction: () -> Void
    let onSecondaryAction: (() -> Void)?
    
    init(worker: Worker, onPrimaryAction: @escaping () -> Void, onSecondaryAction: (() -> Void)? = nil) {
        self.worker = worker
        self.onPrimaryAction = onPrimaryAction
        self.onSecondaryAction = onSecondaryAction
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header: Avatar and info
            HStack(spacing: Theme.Spacing.md) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Theme.Colors.tertiaryBackground)
                        .frame(width: Theme.Sizes.avatarLarge, height: Theme.Sizes.avatarLarge)
                    
                    Image(systemName: worker.avatarName)
                        .font(.system(size: 36))
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    // Verified badge
                    if worker.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .background(Circle().fill(Color(UIColor.systemBackground)).padding(-2))
                            .offset(x: 28, y: 28)
                    }
                }
                
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(worker.name)
                        .font(Theme.Typography.title3)
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "star.fill")
                            .font(.system(size: Theme.Sizes.iconSmall))
                            .foregroundColor(.yellow)
                        
                        Text(String(format: "%.1f", worker.rating))
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.primaryText)
                        
                        Text("·")
                            .foregroundColor(Theme.Colors.secondaryText)
                        
                        Text("\(worker.completedShifts) shifts")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                    
                    // Availability status
                    HStack(spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(worker.isAvailable ? Theme.Colors.success : Color.gray)
                            .frame(width: 8, height: 8)
                        
                        Text(worker.isAvailable ? "Available now" : "Not available")
                            .font(Theme.Typography.caption)
                            .foregroundColor(worker.isAvailable ? Theme.Colors.success : Color.gray)
                    }
                }
                
                Spacer()
            }
            
            // Skills
            if !worker.skills.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(worker.skills, id: \.self) { skill in
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
            
            // Stats row
            HStack(spacing: Theme.Spacing.xl) {
                // Hourly rate
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Hourly Rate")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    Text("$\(Int(worker.hourlyRate))/hr")
                        .font(Theme.Typography.headlineBold)
                        .foregroundColor(Theme.Colors.accent)
                }
                
                Spacer()
                
                // Response time
                VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                    Text("Response Time")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                    
                    Text(worker.responseTime)
                        .font(Theme.Typography.subheadline.weight(.medium))
                        .foregroundColor(Theme.Colors.primaryText)
                }
            }
            
            // Location
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "location.fill")
                    .font(.system(size: Theme.Sizes.iconSmall))
                    .foregroundColor(Theme.Colors.secondaryText)
                
                Text(worker.location.address)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.primaryText)
                    .lineLimit(1)
            }
            
            // Action buttons
            HStack(spacing: Theme.Spacing.md) {
                if let secondaryAction = onSecondaryAction {
                    Button(action: secondaryAction) {
                        Text("Message")
                            .secondaryButtonStyle()
                    }
                }
                
                Button(action: onPrimaryAction) {
                    Text(worker.isAvailable ? "Invite to Shift" : "View Profile")
                        .primaryButtonStyle(isEnabled: worker.isAvailable)
                }
                .disabled(!worker.isAvailable)
            }
        }
        .padding(Theme.Spacing.lg)
        .cardStyle()
    }
}

#Preview {
    VStack {
        WorkerCardView(
            worker: MockData.workers[0],
            onPrimaryAction: {},
            onSecondaryAction: {}
        )
        .padding()
        
        WorkerCardView(
            worker: MockData.workers[3],
            onPrimaryAction: {}
        )
        .padding()
    }
}

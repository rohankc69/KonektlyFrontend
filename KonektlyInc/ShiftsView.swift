//
//  ShiftsView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct ShiftsView: View {
    @AppStorage("userRole") private var userRoleRaw: String = UserRole.worker.rawValue
    @State private var selectedTab = 0
    @State private var searchText = ""
    
    private var userRole: UserRole {
        UserRole(rawValue: userRoleRaw) ?? .worker
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment control
                Picker("Shift Status", selection: $selectedTab) {
                    Text(userRole == .worker ? "Available" : "Open").tag(0)
                    Text(userRole == .worker ? "Applied" : "Active").tag(1)
                    Text("Completed").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(Theme.Spacing.lg)
                
                // Search bar
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.Colors.tertiaryText)
                        .font(.system(size: Theme.Sizes.iconMedium))
                    
                    TextField("Search shifts...", text: $searchText)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primary)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.Colors.tertiaryText)
                                .font(.system(size: Theme.Sizes.iconMedium))
                        }
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.tertiaryBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .padding(.horizontal, Theme.Spacing.lg)
                
                // Content based on selected tab
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.lg) {
                        if selectedTab == 0 {
                            // Available/Open shifts
                            ForEach(MockData.shifts) { shift in
                                ShiftCardView(
                                    shift: shift,
                                    userRole: userRole,
                                    onPrimaryAction: {
                                        handlePrimaryAction(for: shift)
                                    },
                                    onSecondaryAction: {
                                        handleSecondaryAction(for: shift)
                                    }
                                )
                            }
                        } else if selectedTab == 1 {
                            // Applied/Active shifts
                            if userRole == .worker {
                                AppliedShiftsContent()
                            } else {
                                ActiveShiftsContent()
                            }
                        } else {
                            // Completed shifts
                            CompletedShiftsContent()
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
            }
            .navigationTitle(userRole == .worker ? "Shifts" : "Jobs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {}) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(Theme.Colors.primary)
                    }
                }
            }
        }
    }
    
    private func handlePrimaryAction(for shift: Shift) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        // Handle accept/hire action
    }
    
    private func handleSecondaryAction(for shift: Shift) {
        // Handle decline/view details action
    }
}

// MARK: - Applied Shifts Content

struct AppliedShiftsContent: View {
    var body: some View {
        ForEach(Array(MockData.shifts.prefix(2))) { shift in
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ShiftCardView(
                    shift: shift,
                    userRole: .worker,
                    onPrimaryAction: {},
                    onSecondaryAction: nil
                )
                
                // Status badge
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: Theme.Sizes.iconSmall))
                    Text("Application Pending")
                        .font(Theme.Typography.subheadline.weight(.medium))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.small)
            }
        }
    }
}

// MARK: - Active Shifts Content

struct ActiveShiftsContent: View {
    var body: some View {
        ForEach(Array(MockData.shifts.prefix(2))) { shift in
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ShiftCardView(
                    shift: shift,
                    userRole: .business,
                    onPrimaryAction: {},
                    onSecondaryAction: nil
                )
                
                // Worker assigned
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "person.fill.checkmark")
                        .font(.system(size: Theme.Sizes.iconSmall))
                    Text("Worker Assigned: \(MockData.workers[0].name)")
                        .font(Theme.Typography.subheadline.weight(.medium))
                }
                .foregroundColor(Theme.Colors.accent)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.accent.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.small)
            }
        }
    }
}

// MARK: - Completed Shifts Content

struct CompletedShiftsContent: View {
    var body: some View {
        ForEach(Array(MockData.shifts.prefix(3))) { shift in
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                // Completed shift card (simplified)
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(shift.businessName)
                                .font(Theme.Typography.headlineSemibold)
                                .foregroundColor(Theme.Colors.primary)
                            
                            Text(shift.jobTitle)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.tertiaryText)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                            Text("$\(Int(shift.hourlyRate * 5))")
                                .font(Theme.Typography.headlineBold)
                                .foregroundColor(Theme.Colors.accent)
                            
                            Text("\(shift.duration)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.tertiaryText)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.Colors.success)
                            Text("Completed")
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.tertiaryText)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("5.0")
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.tertiaryText)
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
                .cardStyle()
            }
        }
    }
}

#Preview {
    ShiftsView()
}

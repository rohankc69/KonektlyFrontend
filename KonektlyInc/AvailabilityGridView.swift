//
//  AvailabilityGridView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-25.
//

import SwiftUI

struct AvailabilityGridView: View {
    @State private var selectedSlots: Set<AvailabilitySlot> = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let shifts = ["morning", "afternoon", "evening", "overnight"]
    private let shiftLabels = ["Morning", "Afternoon", "Evening", "Overnight"]
    private let shiftTimes = ["6a–12p", "12p–6p", "6p–12a", "12a–6a"]

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                Text("Tap cells to set when you're available")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .padding(.top, Theme.Spacing.md)

                // Grid
                VStack(spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        Text("")
                            .frame(width: 44)

                        ForEach(Array(shiftLabels.enumerated()), id: \.offset) { idx, label in
                            VStack(spacing: 2) {
                                Text(label)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Theme.Colors.primaryText)
                                Text(shiftTimes[idx])
                                    .font(.system(size: 8))
                                    .foregroundColor(Theme.Colors.tertiaryText)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.bottom, Theme.Spacing.sm)

                    // Day rows
                    ForEach(0..<7, id: \.self) { dayIdx in
                        HStack(spacing: 0) {
                            Text(days[dayIdx])
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Theme.Colors.primaryText)
                                .frame(width: 44, alignment: .leading)

                            ForEach(shifts, id: \.self) { shift in
                                let slot = AvailabilitySlot(dayOfWeek: dayIdx, shiftType: shift)
                                let isSelected = selectedSlots.contains(slot)

                                Button {
                                    withAnimation(Theme.Animation.quick) {
                                        if isSelected {
                                            selectedSlots.remove(slot)
                                        } else {
                                            selectedSlots.insert(slot)
                                        }
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(isSelected ? Theme.Colors.accent : Color(UIColor.systemGray5))
                                        .frame(height: 40)
                                        .overlay(
                                            isSelected ?
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white) : nil
                                        )
                                }
                                .frame(maxWidth: .infinity)
                                .padding(2)
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)

                Spacer()

                // Save button
                Button {
                    Task { await saveAvailability() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save Availability")
                        }
                    }
                    .primaryButtonStyle(isEnabled: !isSaving)
                }
                .disabled(isSaving)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("Availability")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if showToast {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: toastIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(.white)
                    Text(toastMessage)
                        .font(Theme.Typography.caption)
                        .foregroundColor(.white)
                }
                .padding(Theme.Spacing.md)
                .background(toastIsError ? Theme.Colors.error : Theme.Colors.success)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task { await loadAvailability() }
    }

    private func loadAvailability() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp: AvailabilityResponse = try await APIClient.shared.request(.myAvailability)
            selectedSlots = Set(resp.slots)
        } catch {
            print("[AVAIL] load error: \(error)")
        }
    }

    private func saveAvailability() async {
        isSaving = true
        defer { isSaving = false }
        let idempotencyKey = UUID().uuidString
        let req = UpdateAvailabilityRequest(slots: Array(selectedSlots))
        do {
            let _: AvailabilityResponse = try await APIClient.shared.request(.updateAvailability(req, idempotencyKey: idempotencyKey))
            toastMessage = "Availability saved!"
            toastIsError = false
            withAnimation { showToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showToast = false }
            }
        } catch {
            toastMessage = error.localizedDescription
            toastIsError = true
            withAnimation { showToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showToast = false }
            }
        }
    }
}

// MARK: - Mini Availability Grid (Read-only, for public profile)

struct MiniAvailabilityGrid: View {
    let slots: [AvailabilitySlot]

    private let days = ["M", "T", "W", "T", "F", "S", "S"]
    private let shifts = ["morning", "afternoon", "evening", "overnight"]
    private let shiftIcons = ["sunrise", "sun.max", "sunset", "moon"]

    private var slotSet: Set<AvailabilitySlot> {
        Set(slots)
    }

    var body: some View {
        VStack(spacing: 2) {
            // Header
            HStack(spacing: 2) {
                Text("")
                    .frame(width: 16)
                ForEach(Array(shiftIcons.enumerated()), id: \.offset) { _, icon in
                    Image(systemName: icon)
                        .font(.system(size: 8))
                        .foregroundColor(Theme.Colors.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<7, id: \.self) { dayIdx in
                HStack(spacing: 2) {
                    Text(days[dayIdx])
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Theme.Colors.secondaryText)
                        .frame(width: 16)

                    ForEach(shifts, id: \.self) { shift in
                        let slot = AvailabilitySlot(dayOfWeek: dayIdx, shiftType: shift)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(slotSet.contains(slot) ? Theme.Colors.accent : Color(UIColor.systemGray5))
                            .frame(height: 14)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}

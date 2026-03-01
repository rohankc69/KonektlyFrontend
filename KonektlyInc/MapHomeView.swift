//
//  MapHomeView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI
import MapKit

// MARK: - MapHomeView

struct MapHomeView: View {
    @AppStorage("userRole") private var userRoleRaw: String = UserRole.worker.rawValue

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    )
    @State private var searchText = ""
    @State private var selectedFilter: FilterChip?
    @State private var showBottomSheet = false
    @State private var selectedShift: Shift?
    @State private var selectedWorker: Worker?

    private var userRole: UserRole {
        UserRole(rawValue: userRoleRaw) ?? .worker
    }

    var body: some View {
        ZStack {
            // Map lives in its own struct - state changes in overlays won't re-render it
            MapLayerView(
                position: $position,
                userRole: userRole,
                selectedShiftID: selectedShift?.id,
                selectedWorkerID: selectedWorker?.id,
                onSelectShift: { shift in
                    withAnimation(Theme.Animation.smooth) {
                        selectedShift = shift
                        showBottomSheet = true
                    }
                },
                onSelectWorker: { worker in
                    withAnimation(Theme.Animation.smooth) {
                        selectedWorker = worker
                        showBottomSheet = true
                    }
                }
            )

            // Overlay controls - isolated from map
            MapOverlayView(
                userRole: userRole,
                searchText: $searchText,
                selectedFilter: $selectedFilter
            )
        }
        .sheet(isPresented: $showBottomSheet, onDismiss: {
            selectedShift = nil
            selectedWorker = nil
        }) {
            BottomSheetView(
                userRole: userRole,
                selectedShift: $selectedShift,
                selectedWorker: $selectedWorker
            )
            .presentationDetents([.height(120), .medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
    }
}

// MARK: - Map Layer (isolated so overlays don't cause re-renders)

private struct MapLayerView: View {
    @Binding var position: MapCameraPosition
    let userRole: UserRole
    let selectedShiftID: UUID?
    let selectedWorkerID: UUID?
    let onSelectShift: (Shift) -> Void
    let onSelectWorker: (Worker) -> Void

    private var annotationItems: [AnnotationItem] {
        if userRole == .worker {
            return MockData.shifts.map {
                AnnotationItem(id: $0.id, coordinate: $0.location.coordinate, isUrgent: $0.isUrgent)
            }
        } else {
            return MockData.workers.map {
                AnnotationItem(id: $0.id, coordinate: $0.location.coordinate, isUrgent: false)
            }
        }
    }

    var body: some View {
        Map(position: $position) {
            ForEach(annotationItems) { item in
                Annotation("", coordinate: item.coordinate) {
                    MapPinView(
                        isUrgent: item.isUrgent,
                        isSelected: item.id == selectedShiftID || item.id == selectedWorkerID
                    ) {
                        if userRole == .worker {
                            if let shift = MockData.shifts.first(where: { $0.id == item.id }) {
                                onSelectShift(shift)
                            }
                        } else {
                            if let worker = MockData.workers.first(where: { $0.id == item.id }) {
                                onSelectWorker(worker)
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Overlay Controls (search + filters + FAB)

private struct MapOverlayView: View {
    let userRole: UserRole
    @Binding var searchText: String
    @Binding var selectedFilter: FilterChip?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.md) {
                // Search bar
                HStack(spacing: Theme.Spacing.md) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Colors.secondaryText)
                            .font(.system(size: Theme.Sizes.iconMedium))

                        TextField(
                            userRole == .worker ? "Search shifts..." : "Search workers...",
                            text: $searchText
                        )
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                        .autocorrectionDisabled()

                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Theme.Colors.secondaryText)
                                    .font(.system(size: Theme.Sizes.iconMedium))
                            }
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    .shadow(
                        color: Theme.Shadows.medium.color,
                        radius: Theme.Shadows.medium.radius,
                        x: Theme.Shadows.medium.x,
                        y: Theme.Shadows.medium.y
                    )

                    Button(action: {}) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: Theme.Sizes.iconMedium))
                            .foregroundColor(Theme.Colors.primaryText)
                            .frame(width: 44, height: 44)
                            .background(Theme.Colors.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                            .shadow(
                                color: Theme.Shadows.medium.color,
                                radius: Theme.Shadows.medium.radius,
                                x: Theme.Shadows.medium.x,
                                y: Theme.Shadows.medium.y
                            )
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(FilterChip.allCases, id: \.self) { filter in
                            FilterChipView(
                                filter: filter,
                                isSelected: selectedFilter == filter
                            ) {
                                withAnimation(Theme.Animation.quick) {
                                    selectedFilter = selectedFilter == filter ? nil : filter
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
            }
            .padding(.top, Theme.Spacing.md)
            .background(
                LinearGradient(
                    colors: [
                        Theme.Colors.background,
                        Theme.Colors.background.opacity(0.95),
                        Theme.Colors.background.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            )

            Spacer()

            // Floating action button
            HStack {
                Spacer()
                Button(action: {}) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                        Text(userRole == .business ? "Post a Job" : "Find Work")
                            .font(Theme.Typography.headlineSemibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.lg)
                    .background(Theme.Colors.primary)
                    .clipShape(Capsule())
                    .shadow(
                        color: Theme.Shadows.large.color,
                        radius: Theme.Shadows.large.radius,
                        x: Theme.Shadows.large.x,
                        y: Theme.Shadows.large.y
                    )
                }
                .padding(.trailing, Theme.Spacing.lg)
            }
            .padding(.bottom, Theme.Spacing.md)
        }
    }
}

// MARK: - Annotation Item

struct AnnotationItem: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let isUrgent: Bool
}

// MARK: - Map Pin View

struct MapPinView: View {
    let isUrgent: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isUrgent ? Theme.Colors.urgent : Theme.Colors.primary)
                    .frame(width: isSelected ? 48 : 40, height: isSelected ? 48 : 40)
                    .shadow(
                        color: Theme.Shadows.medium.color,
                        radius: Theme.Shadows.medium.radius,
                        x: 0,
                        y: Theme.Shadows.medium.y
                    )

                Image(systemName: "figure.stand")
                    .font(.system(size: isSelected ? 24 : 20))
                    .foregroundColor(.white)

                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 56, height: 56)
                }
            }
        }
        .animation(Theme.Animation.smooth, value: isSelected)
    }
}

// MARK: - Filter Chip

enum FilterChip: String, CaseIterable {
    case all = "All"
    case nearby = "Nearby"
    case today = "Today"
    case highPay = "High Pay"
    case verified = "Verified"

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .nearby: return "location.fill"
        case .today: return "calendar"
        case .highPay: return "dollarsign.circle.fill"
        case .verified: return "checkmark.seal.fill"
        }
    }
}

struct FilterChipView: View {
    let filter: FilterChip
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: filter.icon)
                    .font(.system(size: Theme.Sizes.iconSmall))
                Text(filter.rawValue)
                    .font(Theme.Typography.subheadline.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : Theme.Colors.primary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(isSelected ? Theme.Colors.primary : Theme.Colors.cardBackground)
            .clipShape(Capsule())
            .shadow(
                color: Theme.Shadows.small.color,
                radius: Theme.Shadows.small.radius,
                x: 0,
                y: Theme.Shadows.small.y
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bottom Sheet View

struct BottomSheetView: View {
    let userRole: UserRole
    @Binding var selectedShift: Shift?
    @Binding var selectedWorker: Worker?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(userRole == .worker ? "Available Shifts" : "Available Workers")
                        .font(Theme.Typography.headlineBold)
                        .foregroundColor(Theme.Colors.primary)
                    Text("\(userRole == .worker ? MockData.shifts.count : MockData.workers.count) nearby")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.tertiaryText)
                }
                Spacer()
            }
            .padding(Theme.Spacing.lg)

            Divider()

            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    if userRole == .worker {
                        ForEach(MockData.shifts) { shift in
                            ShiftCardView(
                                shift: shift,
                                userRole: userRole,
                                onPrimaryAction: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                },
                                onSecondaryAction: {}
                            )
                        }
                    } else {
                        ForEach(MockData.workers) { worker in
                            WorkerCardView(
                                worker: worker,
                                onPrimaryAction: {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                },
                                onSecondaryAction: {}
                            )
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
    }
}

#Preview {
    MapHomeView()
}

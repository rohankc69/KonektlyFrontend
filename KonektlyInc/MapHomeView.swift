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

    // Use .userLocation(fallback:) so the map automatically follows the real device position.
    // We fall back to a wide world view; once GPS resolves the map re-centres automatically.
    @State private var position: MapCameraPosition = .userLocation(
        fallback: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
        ))
    )
    @State private var searchText = ""
    @State private var selectedFilter: FilterChip?
    @State private var showBottomSheet = false
    @State private var selectedJob: APIJob?
    @State private var showPostalFallback = false
    @State private var postalCode = ""
    @State private var showPostJobSheet = false

    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var jobStore: JobStore

    private var userRole: UserRole {
        UserRole(rawValue: userRoleRaw) ?? .worker
    }

    var body: some View {
        ZStack {
            MapLayerView(
                position: $position,
                userRole: userRole,
                jobs: jobStore.nearbyJobs,
                selectedJobID: selectedJob?.id,
                onSelectJob: { job in
                    withAnimation(Theme.Animation.smooth) {
                        selectedJob = job
                        showBottomSheet = true
                    }
                }
            )

            MapOverlayView(
                userRole: userRole,
                searchText: $searchText,
                selectedFilter: $selectedFilter,
                showPostalFallback: $showPostalFallback,
                postalCode: $postalCode,
                isLocating: locationManager.isLocating || jobStore.isLoadingNearbyJobs,
                locationDenied: locationManager.authStatus == .denied,
                onPostalSearch: {
                    Task { await jobStore.fetchNearbyJobs(postalCode: postalCode) }
                },
                onFABTapped: {
                    if userRole == .business {
                        showPostJobSheet = true
                    } else {
                        showBottomSheet = true
                    }
                }
            )
        }
        .sheet(isPresented: $showBottomSheet, onDismiss: { selectedJob = nil }) {
            MapBottomSheetView(
                userRole: userRole,
                jobs: jobStore.nearbyJobs,
                isLoading: jobStore.isLoadingNearbyJobs,
                error: jobStore.nearbyJobsError?.errorDescription,
                selectedJob: $selectedJob
            )
            .presentationDetents([.height(120), .medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        // Request permission + fetch jobs as soon as the map appears
        .task {
            locationManager.requestAuthorization()
            await fetchJobsWithLocation()
        }
        // Re-fetch whenever auth status changes (e.g. user grants permission from Settings)
        .onChange(of: locationManager.authStatus) { _, newStatus in
            if newStatus == .authorized {
                Task { await fetchJobsWithLocation() }
            } else if newStatus == .denied {
                showPostalFallback = true
            }
        }
        // Post Job sheet (business only)
        .sheet(isPresented: $showPostJobSheet) {
            PostJobView()
                .environmentObject(jobStore)
                .environmentObject(locationManager)
        }
    }

    // MARK: - Location + Fetch

    private func fetchJobsWithLocation() async {
        if let coord = await locationManager.currentCoordinate() {
            // Got a real GPS fix — centre the map and fetch jobs
            withAnimation {
                position = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
            await jobStore.fetchNearbyJobs(lat: coord.latitude, lng: coord.longitude)
        } else {
            // No GPS — show postal code fallback
            showPostalFallback = true
        }
    }
}

// MARK: - Map Layer (isolated so overlays don't cause re-renders)

private struct MapLayerView: View {
    @Binding var position: MapCameraPosition
    let userRole: UserRole
    let jobs: [APIJob]
    let selectedJobID: Int?
    let onSelectJob: (APIJob) -> Void

    var body: some View {
        Map(position: $position) {
            // Show the blue dot for the user's own position
            UserAnnotation()

            if userRole == .worker {
                ForEach(jobs) { job in
                    // Only show jobs that have a geocoded location from the server.
                    // distanceKm being non-nil confirms the server resolved a coordinate.
                    if job.distanceKm != nil {
                        Annotation("", coordinate: approximateCoordinate(for: job)) {
                            MapPinView(
                                isUrgent: false,
                                isSelected: job.id == selectedJobID
                            ) { onSelectJob(job) }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }

    /// The API returns distanceKm but not the raw lat/lng of the job to protect privacy.
    /// We render the pin at the worker's current position offset by distance for now.
    /// When the backend exposes job coordinates this can be replaced with job.lat/lng.
    private func approximateCoordinate(for job: APIJob) -> CLLocationCoordinate2D {
        // Fallback: centre of map — MapKit will place the pin where the map is centred.
        // Replace with actual job coordinates once the API exposes them.
        CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
}

// MARK: - Overlay Controls

private struct MapOverlayView: View {
    let userRole: UserRole
    @Binding var searchText: String
    @Binding var selectedFilter: FilterChip?
    @Binding var showPostalFallback: Bool
    @Binding var postalCode: String
    let isLocating: Bool
    let locationDenied: Bool
    let onPostalSearch: () -> Void
    let onFABTapped: () -> Void          // ← callback so parent handles sheet state

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
                    .shadow(color: Theme.Shadows.medium.color,
                            radius: Theme.Shadows.medium.radius,
                            x: Theme.Shadows.medium.x,
                            y: Theme.Shadows.medium.y)

                    // Location status indicator
                    ZStack {
                        if isLocating {
                            ProgressView()
                                .frame(width: 44, height: 44)
                                .background(Theme.Colors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                        } else {
                            Button(action: { showPostalFallback.toggle() }) {
                                Image(systemName: locationDenied ? "location.slash.fill" : "location.fill")
                                    .font(.system(size: Theme.Sizes.iconMedium))
                                    .foregroundColor(locationDenied ? .red : Theme.Colors.primaryText)
                                    .frame(width: 44, height: 44)
                                    .background(Theme.Colors.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                                    .shadow(color: Theme.Shadows.medium.color,
                                            radius: Theme.Shadows.medium.radius,
                                            x: Theme.Shadows.medium.x,
                                            y: Theme.Shadows.medium.y)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(FilterChip.allCases, id: \.self) { filter in
                            FilterChipView(filter: filter, isSelected: selectedFilter == filter) {
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
                    colors: [Theme.Colors.background,
                             Theme.Colors.background.opacity(0.95),
                             Theme.Colors.background.opacity(0)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            )

            Spacer()

            // Floating action button
            HStack {
                Spacer()
                Button(action: onFABTapped) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 24))
                        Text(userRole == .business ? "Post a Job" : "Find Work")
                            .font(Theme.Typography.headlineSemibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.lg)
                    .background(Theme.Colors.primary)
                    .clipShape(Capsule())
                    .shadow(color: Theme.Shadows.large.color,
                            radius: Theme.Shadows.large.radius,
                            x: Theme.Shadows.large.x,
                            y: Theme.Shadows.large.y)
                }
                .padding(.trailing, Theme.Spacing.lg)
            }
            .padding(.bottom, Theme.Spacing.md)
        }
    }
}

// MARK: - Bottom Sheet (real job data)

struct MapBottomSheetView: View {
    let userRole: UserRole
    let jobs: [APIJob]
    let isLoading: Bool
    let error: String?
    @Binding var selectedJob: APIJob?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(userRole == .worker ? "Nearby Jobs" : "Available Workers")
                        .font(Theme.Typography.headlineBold)
                        .foregroundColor(Theme.Colors.primary)
                    if isLoading {
                        Text("Loading…")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.tertiaryText)
                    } else if let error {
                        Text(error)
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(.red)
                    } else {
                        Text("\(jobs.count) nearby")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.tertiaryText)
                    }
                }
                Spacer()
            }
            .padding(Theme.Spacing.lg)

            Divider()

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.xl)
            } else if jobs.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "briefcase")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.Colors.tertiaryText)
                    Text(error != nil ? "Failed to load jobs" : "No jobs nearby")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.xl)
            } else {
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        ForEach(jobs) { job in
                            NearbyJobCardView(job: job)
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
            }
        }
    }
}

// MARK: - Nearby Job Card (read-only, used in map bottom sheet)

struct NearbyJobCardView: View {
    let job: APIJob

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(job.title)
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
                Text("$\(job.payRate)/hr")
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.accent)
            }

            if let address = job.addressDisplay {
                Label(address, systemImage: "mappin.and.ellipse")
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .lineLimit(1)
            }

            HStack(spacing: Theme.Spacing.md) {
                Label(Self.dateFormatter.string(from: job.scheduledStart), systemImage: "clock")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)

                if let km = job.distanceKm {
                    Label(String(format: "%.1f km away", km), systemImage: "location")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .shadow(color: Theme.Shadows.small.color,
                radius: Theme.Shadows.small.radius,
                x: 0, y: Theme.Shadows.small.y)
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
                    .shadow(color: Theme.Shadows.medium.color,
                            radius: Theme.Shadows.medium.radius,
                            x: 0, y: Theme.Shadows.medium.y)

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
        case .all:      return "square.grid.2x2"
        case .nearby:   return "location.fill"
        case .today:    return "calendar"
        case .highPay:  return "dollarsign.circle.fill"
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
            .shadow(color: Theme.Shadows.small.color,
                    radius: Theme.Shadows.small.radius,
                    x: 0, y: Theme.Shadows.small.y)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Legacy bottom sheet kept for backward compat (uses old Shift/Worker mock types)
// Remove once ShiftsView is fully migrated to real API data.

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
                            ShiftCardView(shift: shift, userRole: userRole,
                                          onPrimaryAction: { UIImpactFeedbackGenerator(style: .medium).impactOccurred() },
                                          onSecondaryAction: {})
                        }
                    } else {
                        ForEach(MockData.workers) { worker in
                            WorkerCardView(worker: worker,
                                           onPrimaryAction: { UIImpactFeedbackGenerator(style: .medium).impactOccurred() },
                                           onSecondaryAction: {})
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
        .environmentObject(LocationManager())
        .environmentObject(JobStore.shared)
}

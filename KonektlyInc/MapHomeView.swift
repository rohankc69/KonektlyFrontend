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
    @State private var sheetDetent: PresentationDetent = .medium
    @State private var selectedJob: APIJob?
    @State private var showPostalFallback = false
    @State private var postalCode = ""
    @State private var showPostJobSheet = false

    // Last known location — reused when filter chips change so we don't re-request GPS
    @State private var lastLat: Double? = nil
    @State private var lastLng: Double? = nil
    @State private var lastPostalCode: String? = nil

    // Stable approximate centers: once recorded for a job, never updated even if the
    // server re-fuzzes coordinates on the next fetch. Keyed by job ID.
    @State private var stableApproxCenters: [Int: CLLocationCoordinate2D] = [:]

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
                stableApproxCenters: stableApproxCenters,
                selectedJobID: selectedJob?.id,
                onSelectJob: { job in
                    withAnimation(Theme.Animation.smooth) {
                        selectedJob = job
                        sheetDetent = .medium
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
                onFilterChanged: { newFilter in
                    Task { await refetchWithFilter(newFilter) }
                },
                onPostalSearch: {
                    lastPostalCode = postalCode
                    lastLat = nil
                    lastLng = nil
                    Task {
                        await jobStore.fetchNearbyJobs(
                            postalCode: postalCode,
                            radius: selectedFilter == .nearby ? nil : 25,
                            filter: selectedFilter?.apiValue
                        )
                    }
                },
                onFABTapped: {
                    if userRole == .business {
                        showPostJobSheet = true
                    } else {
                        sheetDetent = .medium
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
            // medium + large only — no tiny strip detent
            .presentationDetents([.medium, .large], selection: $sheetDetent)
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .presentationCornerRadius(16)
        }
        // Request permission + fetch jobs as soon as the map appears
        .task {
            locationManager.requestAuthorization()
            await fetchJobsWithLocation()
        }
        // Cache the first seen approximate center for each job — never overwrite it
        // so circles don't drift when the server re-fuzzes on subsequent fetches
        .onChange(of: jobStore.nearbyJobs) { _, jobs in
            for job in jobs where job.locationIsApproximate == true {
                guard stableApproxCenters[job.id] == nil, let coord = job.coordinate else { continue }
                stableApproxCenters[job.id] = coord
            }
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
            lastLat = coord.latitude
            lastLng = coord.longitude
            lastPostalCode = nil
            withAnimation {
                position = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
            await jobStore.fetchNearbyJobs(
                lat: coord.latitude, lng: coord.longitude,
                radius: selectedFilter == .nearby ? nil : 25,
                filter: selectedFilter?.apiValue
            )
        } else {
            showPostalFallback = true
        }
    }

    /// Re-fetch with the current cached location whenever the active filter changes.
    private func refetchWithFilter(_ filter: FilterChip?) async {
        // nearby ignores radius server-side; omit it to keep the request clean
        let radius = filter == .nearby ? nil : 25
        await jobStore.fetchNearbyJobs(
            lat: lastLat, lng: lastLng,
            postalCode: lastPostalCode,
            radius: radius,
            filter: filter?.apiValue,
            forceRefresh: true
        )
    }
}

// MARK: - Map Layer (isolated so overlays don't cause re-renders)

private struct MapLayerView: View {
    @Binding var position: MapCameraPosition
    let userRole: UserRole
    let jobs: [APIJob]
    let stableApproxCenters: [Int: CLLocationCoordinate2D]
    let selectedJobID: Int?
    let onSelectJob: (APIJob) -> Void

    var body: some View {
        Map(position: $position) {
            UserAnnotation()

            if userRole == .worker {
                ForEach(jobs) { job in
                    if job.locationIsApproximate == true {
                        // Use the stable cached center so the circle doesn't drift on refresh.
                        // Fall back to current coordinate only if not yet cached.
                        if let center = stableApproxCenters[job.id] ?? job.coordinate {
                            // Semi-transparent radius blob — 1500 m covers the server's ±800–1500 m fuzz
                            MapCircle(center: center, radius: 1500)
                                .foregroundStyle(Color.blue.opacity(0.10))
                                .stroke(Color.blue.opacity(0.22), lineWidth: 1.5)

                            // Tappable annotation at center so user can open the job card
                            Annotation("", coordinate: center) {
                                ApproximateJobMarker(isSelected: job.id == selectedJobID) {
                                    onSelectJob(job)
                                }
                            }
                        }
                    } else if let coordinate = job.coordinate {
                        Annotation("", coordinate: coordinate) {
                            MapPinView(
                                isUrgent: false,
                                isSelected: job.id == selectedJobID,
                                isApproximate: false
                            ) { onSelectJob(job) }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
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
    let onFilterChanged: (FilterChip?) -> Void
    let onPostalSearch: () -> Void
    let onFABTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top controls — sits below the status bar via safeAreaInset background
            VStack(spacing: Theme.Spacing.sm) {
                // Search bar + location button
                HStack(spacing: Theme.Spacing.sm) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .font(.system(size: Theme.Sizes.iconMedium))

                        TextField(
                            userRole == .worker ? "Search shifts..." : "Search workers...",
                            text: $searchText
                        )
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.primaryText)
                        .autocorrectionDisabled()

                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Theme.Colors.secondaryText)
                                    .font(.system(size: Theme.Sizes.iconMedium))
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    .shadow(color: Theme.Shadows.medium.color,
                            radius: Theme.Shadows.medium.radius,
                            x: 0, y: Theme.Shadows.medium.y)

                    // Location button — fixed 44×44 touch target (HIG minimum)
                    Button(action: { showPostalFallback.toggle() }) {
                        Group {
                            if isLocating {
                                ProgressView()
                                    .tint(Theme.Colors.primaryText)
                            } else {
                                Image(systemName: locationDenied ? "location.slash.fill" : "location.fill")
                                    .font(.system(size: Theme.Sizes.iconMedium))
                                    .foregroundStyle(locationDenied ? Theme.Colors.error : Theme.Colors.primaryText)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                        .shadow(color: Theme.Shadows.medium.color,
                                radius: Theme.Shadows.medium.radius,
                                x: 0, y: Theme.Shadows.medium.y)
                    }
                    .disabled(isLocating)
                }
                .padding(.horizontal, Theme.Spacing.lg)

                // Filter chips — contentMargins keeps leading/trailing space
                // while scrollClipDisabled lets chip shadows breathe at the edges
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(FilterChip.allCases, id: \.self) { filter in
                            FilterChipView(filter: filter, isSelected: selectedFilter == filter) {
                                // Compute new selection before mutating state so the
                                // API call uses the correct value
                                let newFilter: FilterChip? = selectedFilter == filter ? nil : filter
                                withAnimation(Theme.Animation.quick) {
                                    selectedFilter = newFilter
                                }
                                onFilterChanged(newFilter)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .contentMargins(.horizontal, Theme.Spacing.lg, for: .scrollContent)
                .scrollClipDisabled()
            }
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.md)
            .background(
                LinearGradient(
                    colors: [
                        Theme.Colors.background,
                        Theme.Colors.background.opacity(0.98),
                        Theme.Colors.background.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
            )

            Spacer()

            // FAB — trailing, above the home indicator / tab bar
            HStack {
                Spacer()
                Button(action: onFABTapped) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: userRole == .business ? "plus.circle.fill" : "magnifyingglass.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text(userRole == .business ? "Post a Job" : "Find Work")
                            .font(Theme.Typography.headlineSemibold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, 14)
                    .background(Theme.Colors.primaryText)
                    .clipShape(Capsule())
                    .shadow(color: Theme.Shadows.large.color,
                            radius: Theme.Shadows.large.radius,
                            x: 0, y: Theme.Shadows.large.y)
                }
                .padding(.trailing, Theme.Spacing.lg)
            }
            .safeAreaPadding(.bottom, Theme.Spacing.md)
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
            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(userRole == .worker ? "Nearby Jobs" : "Available Workers")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primaryText)
                    Group {
                        if isLoading {
                            Text("Loading…")
                        } else if let error {
                            Text(error)
                                .foregroundStyle(Theme.Colors.error)
                        } else {
                            Text("\(jobs.count) nearby")
                        }
                    }
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.sm)

            Divider()

            if isLoading {
                VStack(spacing: Theme.Spacing.md) {
                    ProgressView()
                    Text("Finding jobs near you…")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xxxl)
            } else if jobs.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: error != nil ? "wifi.exclamationmark" : "briefcase")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(Theme.Colors.tertiaryText)
                    Text(error != nil ? "Failed to load jobs" : "No jobs nearby")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.Colors.secondaryText)
                    if error == nil {
                        Text("Try expanding your search area")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xxxl)
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(jobs) { job in
                            NearbyJobCardView(job: job)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.lg)
                }
            }
        }
    }
}

// MARK: - Nearby Job Card (read-only, used in map bottom sheet)

struct NearbyJobCardView: View {
    let job: APIJob
    @State private var showSubscription = false
    @StateObject private var subscriptionManager = SubscriptionManager.shared

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

            if job.locationIsApproximate == true && !subscriptionManager.isKonektlyPlus {
                // Free user — show radius text, never expose a drifting address
                Button { showSubscription = true } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "circle.dashed")
                            .font(.system(size: 13))
                        Text("Within ~1.5 km · Unlock exact location")
                            .font(Theme.Typography.subheadline)
                            .lineLimit(1)
                    }
                    .foregroundStyle(Theme.Colors.accent)
                }
                .buttonStyle(.plain)
            } else if let address = job.addressDisplay {
                Label(address, systemImage: "mappin.and.ellipse")
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)
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
    let isApproximate: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                // Approximate location indicator (larger, semi-transparent circle)
                if isApproximate {
                    Circle()
                        .fill((isUrgent ? Theme.Colors.urgent : Theme.Colors.primary).opacity(0.2))
                        .frame(width: isSelected ? 80 : 70, height: isSelected ? 80 : 70)
                }
                
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
                
                // Small indicator badge for approximate locations
                if isApproximate && !isSelected {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(isUrgent ? Theme.Colors.urgent : Theme.Colors.primary, lineWidth: 2)
                        )
                        .offset(x: 14, y: -14)
                }
            }
        }
        .animation(Theme.Animation.smooth, value: isSelected)
    }
}

// MARK: - Approximate Job Marker (free users)

/// Small pulsing dot shown at the centre of an approximate-location radius blob.
/// Deliberately vague — communicates "a job exists in this area" without implying precision.
struct ApproximateJobMarker: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(isSelected ? 0.3 : 0.18))
                    .frame(width: isSelected ? 36 : 28, height: isSelected ? 36 : 28)
                Circle()
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: isSelected ? 14 : 10, height: isSelected ? 14 : 10)
                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
        }
        .animation(Theme.Animation.smooth, value: isSelected)
    }
}

// MARK: - Filter Chip

enum FilterChip: String, CaseIterable {
    case all      = "All"
    case nearby   = "Nearby"
    case today    = "Today"
    case highPay  = "High Pay"
    case verified = "Verified"

    /// Value sent to GET /api/v1/jobs/nearby/?filter=
    var apiValue: String {
        switch self {
        case .all:      return "all"
        case .nearby:   return "nearby"
        case .today:    return "today"
        case .highPay:  return "high_pay"
        case .verified: return "verified"
        }
    }

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

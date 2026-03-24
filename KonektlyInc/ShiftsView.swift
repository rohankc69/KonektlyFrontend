//
//  ShiftsView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI
import CoreLocation

struct ShiftsView: View {
    @AppStorage("userRole") private var userRoleRaw: String = UserRole.worker.rawValue
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showLocationBanner = false   // non-blocking "enable GPS" hint

    @EnvironmentObject private var jobStore: JobStore
    @EnvironmentObject private var locationManager: LocationManager

    private var userRole: UserRole {
        UserRole(rawValue: userRoleRaw) ?? .worker
    }

    // MARK: - Filtered lists

    private var filteredNearbyJobs: [APIJob] {
        guard !searchText.isEmpty else { return jobStore.nearbyJobs }
        let q = searchText.lowercased()
        return jobStore.nearbyJobs.filter {
            $0.title.lowercased().contains(q) ||
            ($0.description?.lowercased().contains(q) ?? false) ||
            ($0.addressDisplay?.lowercased().contains(q) ?? false)
        }
    }

    // Business tab 0 — open jobs
    private var openPostedJobs: [APIJob] {
        let jobs = jobStore.postedJobs.filter { $0.statusEnum == .open }
        guard !searchText.isEmpty else { return jobs }
        let q = searchText.lowercased()
        return jobs.filter { $0.title.lowercased().contains(q) }
    }

    // Business tab 1 — active (filled = worker hired, shift scheduled)
    private var activePostedJobs: [APIJob] {
        jobStore.postedJobs.filter { $0.statusEnum == .filled }
    }

    // Business tab 2 — completed
    private var completedPostedJobs: [APIJob] {
        jobStore.postedJobs.filter { $0.statusEnum == .completed }
    }

    // Worker tab 1 — applied (pending + active-accepted), pre-filtered by JobStore
    private var appliedApplications: [MyApplicationItem] {
        guard !searchText.isEmpty else { return jobStore.activeApplications }
        let q = searchText.lowercased()
        return jobStore.activeApplications.filter { $0.job.title.lowercased().contains(q) }
    }

    // Worker tab 2 — completed (accepted + job.status==completed), pre-filtered by JobStore
    private var completedApplications: [MyApplicationItem] {
        jobStore.completedApplications
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Shift Status", selection: $selectedTab) {
                    Text(userRole == .worker ? "Available" : "Open").tag(0)
                    Text(userRole == .worker ? "Applied"   : "Active").tag(1)
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

                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.lg) {
                        if selectedTab == 0 {
                            availableTab
                        } else if selectedTab == 1 {
                            if userRole == .worker { appliedTab } else { activeTab }
                        } else {
                            completedTab
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
            // Non-blocking GPS banner — shown once when permission denied
            .safeAreaInset(edge: .top, spacing: 0) {
                if showLocationBanner {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "location.slash.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.primaryText)
                        Text("Enable location to see how far jobs are from you")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                        Spacer()
                        Button {
                            withAnimation { showLocationBanner = false }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.Colors.tertiaryText)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.tertiaryBackground)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .task {
                locationManager.requestAuthorization()
                let coord = await locationManager.currentCoordinate()

                // Show banner once if GPS denied — never block the list
                if coord == nil && locationManager.authStatus == .denied {
                    withAnimation { showLocationBanner = true }
                }

                // Tab 0: nearby jobs (worker) OR posted jobs (business)
                if userRole == .worker {
                    if jobStore.nearbyJobs.isEmpty && !jobStore.isLoadingNearbyJobs {
                        await jobStore.fetchNearbyJobs(lat: coord?.latitude, lng: coord?.longitude)
                    }
                    // Pre-fetch applications so tabs 1 & 2 are ready
                    if jobStore.activeApplications.isEmpty && !jobStore.isLoadingMyApplications {
                        await jobStore.fetchMyApplications(lat: coord?.latitude, lng: coord?.longitude)
                    }
                } else {
                    // Business: always refresh posted jobs on view load
                    await jobStore.fetchPostedJobs()
                }
            }
            .refreshable {
                let coord = await locationManager.currentCoordinate()
                if userRole == .worker {
                    // Run both fetches truly in parallel and wait for both to complete
                    // forceRefresh: true bypasses isLoading guard so a guard from
                    // a concurrent .task never blocks the pull-to-refresh
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            await jobStore.fetchNearbyJobs(
                                lat: coord?.latitude, lng: coord?.longitude,
                                forceRefresh: true
                            )
                        }
                        group.addTask {
                            await jobStore.fetchMyApplications(
                                lat: coord?.latitude, lng: coord?.longitude,
                                forceRefresh: true
                            )
                        }
                    }
                } else {
                    await jobStore.fetchPostedJobs(forceRefresh: true)
                }
            }
            // Refresh applications when switching to worker tabs 1 or 2
            .onChange(of: selectedTab) { _, tab in
                if userRole == .worker && (tab == 1 || tab == 2) {
                    Task {
                        let coord = await locationManager.currentCoordinate()
                        await jobStore.fetchMyApplications(
                            lat: coord?.latitude,
                            lng: coord?.longitude
                        )
                    }
                }
            }
            // When a new application is inserted (after apply), switch to Applied tab
            // and do a background server sync to get the real server-assigned timestamps
            .onChange(of: jobStore.activeApplications.count) { oldCount, newCount in
                guard userRole == .worker, newCount > oldCount else { return }
                withAnimation { selectedTab = 1 }
                // Background sync — replace optimistic insert with real server data
                Task {
                    let coord = await locationManager.currentCoordinate()
                    await jobStore.fetchMyApplications(
                        lat: coord?.latitude,
                        lng: coord?.longitude
                    )
                }
            }
        }
    }

    // MARK: - Tab 0: Available / Open

    @ViewBuilder
    private var availableTab: some View {
        if userRole == .worker {
            if jobStore.isLoadingNearbyJobs {
                loadingView("Loading jobs…")
            } else if let error = jobStore.nearbyJobsError {
                errorView(error.errorDescription ?? "Failed to load jobs") {
                    Task {
                        let coord = await locationManager.currentCoordinate()
                        await jobStore.fetchNearbyJobs(lat: coord?.latitude, lng: coord?.longitude)
                    }
                }
            } else if filteredNearbyJobs.isEmpty {
                emptyView("briefcase",
                          searchText.isEmpty ? "No jobs nearby right now" : "No results for \"\(searchText)\"")
            } else {
                ForEach(filteredNearbyJobs) { job in NearbyJobListCard(job: job) }
            }
        } else {
            // Business — open jobs
            if jobStore.isLoadingPostedJobs {
                loadingView("Loading jobs…")
            } else if let error = jobStore.postedJobsError {
                errorView(error.errorDescription ?? "Failed to load jobs") {
                    Task { await jobStore.fetchPostedJobs() }
                }
            } else if openPostedJobs.isEmpty {
                emptyView("plus.square.dashed",
                          searchText.isEmpty
                            ? "No open jobs — tap Post a Job to get started"
                            : "No results for \"\(searchText)\"")
            } else {
                ForEach(openPostedJobs) { job in PostedJobListCard(job: job) }
            }
        }
    }

    // MARK: - Tab 1: Applied (worker) / Active (business)

    @ViewBuilder
    private var appliedTab: some View {
        if jobStore.isLoadingMyApplications {
            loadingView("Loading applications…")
        } else if let error = jobStore.myApplicationsError {
            errorView(error.errorDescription ?? "Failed to load applications") {
                Task {
                    let coord = await locationManager.currentCoordinate()
                    await jobStore.fetchMyApplications(lat: coord?.latitude, lng: coord?.longitude)
                }
            }
        } else if appliedApplications.isEmpty {
            emptyView("tray",
                      searchText.isEmpty
                        ? "No active applications"
                        : "No results for \"\(searchText)\"")
        } else {
            ForEach(appliedApplications) { item in
                MyApplicationCard(item: item)
            }
        }
    }

    @ViewBuilder
    private var activeTab: some View {
        if jobStore.isLoadingPostedJobs {
            loadingView("Loading active shifts…")
        } else if let error = jobStore.postedJobsError {
            errorView(error.errorDescription ?? "Failed to load shifts") {
                Task { await jobStore.fetchPostedJobs() }
            }
        } else if activePostedJobs.isEmpty {
            emptyView("person.badge.clock", "No active shifts yet — hire a worker to see them here")
        } else {
            ForEach(activePostedJobs) { job in PostedJobListCard(job: job) }
        }
    }

    // MARK: - Tab 2: Completed

    @ViewBuilder
    private var completedTab: some View {
        if userRole == .worker {
            if jobStore.isLoadingMyApplications {
                loadingView("Loading…")
            } else if completedApplications.isEmpty {
                emptyView("checkmark.seal", "No completed shifts yet")
            } else {
                ForEach(completedApplications) { item in
                    CompletedWorkerCard(item: item)
                }
            }
        } else {
            if completedPostedJobs.isEmpty {
                emptyView("checkmark.seal", "No completed jobs yet")
            } else {
                ForEach(completedPostedJobs) { job in
                    CompletedBusinessCard(job: job)
                }
            }
        }
    }

    // MARK: - Shared state views

    @ViewBuilder
    private func loadingView(_ label: String) -> some View {
        ProgressView(label)
            .font(Theme.Typography.subheadline)
            .foregroundColor(Theme.Colors.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(Theme.Spacing.xl)
    }

    @ViewBuilder
    private func emptyView(_ icon: String, _ message: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(Theme.Colors.tertiaryText)
            Text(message)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xl)
    }

    @ViewBuilder
    private func errorView(_ message: String, retry: @escaping () -> Void) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 36))
                .foregroundColor(Theme.Colors.tertiaryText)
            Text(message)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
            Button("Try Again", action: retry)
                .font(Theme.Typography.subheadline.weight(.semibold))
                .foregroundColor(Theme.Colors.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xl)
    }
}

// MARK: - Distance Badge (shared by all cards)
// Spec: null → hide, < 1000m → "800 m", ≥ 1000m → "2.3 km"

private struct DistanceBadge: View {
    let formatted: String
    var body: some View {
        Label(formatted, systemImage: "mappin.and.ellipse")
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.secondaryText)
    }
}

// MARK: - Nearby Job List Card (worker tab 0)

struct NearbyJobListCard: View {
    let job: APIJob
    @EnvironmentObject private var jobStore: JobStore
    @State private var showSubscription = false
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(job.title)
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.primaryText)
                    if let address = job.addressDisplay {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text(address)
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.secondaryText)
                                .lineLimit(1)
                            
                            // Privacy indicator for approximate locations - tappable to upgrade
                            if job.locationIsApproximate == true && !subscriptionManager.isKonektlyPlus {
                                Button {
                                    showSubscription = true
                                } label: {
                                    Image(systemName: "location.circle")
                                        .font(.system(size: 12))
                                        .foregroundColor(Theme.Colors.accent)
                                }
                            } else if job.locationIsApproximate == true {
                                Image(systemName: "location.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.tertiaryText)
                            }
                        }
                    }
                }
                Spacer()
                // Pay rate chip — primaryText (black/white) per theme
                Text("$\(job.payRate)/hr")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.primaryText)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.primaryText.opacity(0.08))
                    .clipShape(Capsule())
            }

            HStack(spacing: Theme.Spacing.md) {
                Label(Self.df.string(from: job.scheduledStart), systemImage: "clock")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
                // Distance badge — hidden if null (GPS denied or not sent)
                if let dist = job.formattedDistance {
                    DistanceBadge(formatted: dist)
                }
                Spacer()
                // Status chip — open → muted green, others → neutral secondaryText
                let isOpen = job.statusEnum == .open
                Text(job.status.capitalized)
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundColor(isOpen ? Theme.Colors.success : Theme.Colors.secondaryText)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 3)
                    .background((isOpen ? Theme.Colors.success : Theme.Colors.secondaryText).opacity(0.10))
                    .clipShape(Capsule())
            }
            
            // Show upgrade prompt for approximate locations (only for non-subscribers)
            if job.locationIsApproximate == true && !subscriptionManager.isKonektlyPlus {
                LocationBlurPrompt {
                    showSubscription = true
                }
            }

            Button {
                Task { await jobStore.applyForJob(jobId: job.id) }
            } label: {
                HStack {
                    if jobStore.isApplying { ProgressView().tint(.white) }
                    Text(applyButtonTitle)
                        .font(Theme.Typography.subheadline.weight(.semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .background(applyButtonDisabled ? Theme.Colors.tertiaryText : Theme.Colors.primary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
            }
            .disabled(applyButtonDisabled)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .shadow(color: Theme.Shadows.small.color,
                radius: Theme.Shadows.small.radius, x: 0, y: Theme.Shadows.small.y)
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

    private var alreadyApplied: Bool {
        jobStore.hasApplied(jobId: job.id)
    }
    private var jobFilled: Bool {
        job.statusEnum == .filled || job.statusEnum == .cancelled
    }
    private var applyButtonDisabled: Bool {
        jobStore.isApplying || alreadyApplied || jobFilled
    }
    private var applyButtonTitle: String {
        if alreadyApplied { return "Applied" }
        if jobFilled       { return "Position Filled" }
        return "Apply Now"
    }
}

// MARK: - Posted Job List Card (business tab 0 & 1)

struct PostedJobListCard: View {
    let job: APIJob
    @EnvironmentObject private var jobStore: JobStore
    @State private var isExpanded = false
    @State private var localApplications: [JobApplication] = []
    @State private var isLoadingApplicants = false
    @State private var applicantsLoaded = false
    @State private var showCompleteError: String? = nil

    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()

    private var statusColor: Color {
        switch job.statusEnum {
        case .open:      return Theme.Colors.success
        case .filled:    return Theme.Colors.primaryText
        case .cancelled: return Theme.Colors.error
        case .completed: return Theme.Colors.secondaryText
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {

            // Top row — title + pay chip + status chip
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(job.title)
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.primaryText)
                    if let address = job.addressDisplay {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text(address)
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.secondaryText)
                                .lineLimit(1)
                            
                            // Privacy indicator for approximate locations
                            if job.locationIsApproximate == true {
                                Image(systemName: "location.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.tertiaryText)
                            }
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                    Text("$\(job.payRate)/hr")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.primaryText)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.primaryText.opacity(0.08))
                        .clipShape(Capsule())
                    Text(job.status.capitalized)
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.10))
                        .clipShape(Capsule())
                }
            }

            // Second row — clock + distance
            HStack(spacing: Theme.Spacing.md) {
                Label(Self.df.string(from: job.scheduledStart), systemImage: "clock")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
                if let dist = job.formattedDistance {
                    DistanceBadge(formatted: dist)
                }
            }

            // "Mark as Complete" — only on filled jobs (shift scheduled, worker hired)
            if job.statusEnum == .filled {
                Button {
                    showCompleteError = nil
                    Task {
                        let success = await jobStore.markJobComplete(jobId: job.id)
                        if !success {
                            showCompleteError = jobStore.completeError?.errorDescription
                                ?? "Could not mark job complete. Please try again."
                        }
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        if jobStore.isCompleting {
                            ProgressView().tint(.white).scaleEffect(0.85)
                        } else {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Mark as Complete")
                                .font(Theme.Typography.subheadline.weight(.semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(jobStore.isCompleting
                                ? Theme.Colors.primaryText.opacity(0.4)
                                : Theme.Colors.primaryText)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                }
                .buttonStyle(.plain)
                .disabled(jobStore.isCompleting)

                if let errMsg = showCompleteError {
                    Text(errMsg)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.error)
                        .padding(.top, Theme.Spacing.xs)
                }
            }

            // View applicants button — open jobs only
            if job.statusEnum == .open {
                Button {
                    let willExpand = !isExpanded
                    withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
                    if willExpand && !applicantsLoaded {
                        Task { await loadApplicants() }
                    }
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text(isExpanded ? "Hide Applicants" : "View Applicants")
                            .font(Theme.Typography.caption.weight(.semibold))
                        if !localApplications.isEmpty {
                            Text("(\(localApplications.count))")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                        Spacer()
                        if isLoadingApplicants {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .foregroundColor(Theme.Colors.primaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.tertiaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                }
                .buttonStyle(.plain)

                if isExpanded {
                    if isLoadingApplicants {
                        ProgressView("Loading applicants…")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.sm)
                    } else if localApplications.isEmpty {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "tray")
                                .foregroundColor(Theme.Colors.tertiaryText)
                            Text("No applications yet")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.tertiaryText)
                        }
                        .padding(.vertical, Theme.Spacing.sm)
                    } else {
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(localApplications) { app in
                                ApplicantRow(
                                    application: app,
                                    jobId: job.id,
                                    onHired: { hired in
                                        localApplications = localApplications.map { a in
                                            if a.id == hired.id { return hired }
                                            if a.status == ApplicationStatus.pending.rawValue {
                                                return a.withStatus(.rejected)
                                            }
                                            return a
                                        }
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .shadow(color: Theme.Shadows.small.color,
                radius: Theme.Shadows.small.radius, x: 0, y: Theme.Shadows.small.y)
    }

    private func loadApplicants() async {
        guard !isLoadingApplicants else { return }
        isLoadingApplicants = true
        defer { isLoadingApplicants = false }
        localApplications = await jobStore.fetchApplicationsForCard(jobId: job.id)
        applicantsLoaded = true
    }
}

// MARK: - Applicant Row (inside PostedJobListCard)

struct ApplicantRow: View {
    let application: JobApplication
    let jobId: Int
    var onHired: ((JobApplication) -> Void)? = nil
    @EnvironmentObject private var jobStore: JobStore

    private var statusColor: Color {
        switch ApplicationStatus(rawValue: application.status) ?? .pending {
        case .pending:  return .orange
        case .accepted: return Theme.Colors.success
        case .rejected: return Theme.Colors.tertiaryText
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Avatar initials
            ZStack {
                Circle()
                    .fill(Theme.Colors.tertiaryBackground)
                    .frame(width: 36, height: 36)
                Text(initials)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.primaryText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(application.firstName) \(application.lastName)")
                    .font(Theme.Typography.subheadline.weight(.medium))
                    .foregroundColor(Theme.Colors.primaryText)
                if let note = application.coverNote, !note.isEmpty {
                    Text(note)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Status or Hire button
            if application.status == ApplicationStatus.pending.rawValue {
                Button {
                    Task {
                        if let hired = await jobStore.hireWorker(
                            jobId: jobId,
                            applicationId: application.id
                        ) {
                            onHired?(hired)
                        }
                    }
                } label: {
                    if jobStore.isHiring {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Text("Hire")
                            .font(Theme.Typography.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, 6)
                            .background(Theme.Colors.primaryText)
                            .clipShape(Capsule())
                    }
                }
                .buttonStyle(.plain)
                .disabled(jobStore.isHiring)
            } else {
                Text(application.status.capitalized)
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private var initials: String {
        let f = application.firstName.prefix(1)
        let l = application.lastName.prefix(1)
        return "\(f)\(l)".uppercased()
    }
}

// MARK: - My Application Card (worker tab 1 — Applied)

struct MyApplicationCard: View {
    let item: MyApplicationItem

    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()

    private var statusLabel: String {
        switch item.statusEnum {
        case .pending:  return "Pending"
        case .accepted: return "Hired"
        case .rejected: return "Not selected"
        }
    }

    private var statusColor: Color {
        switch item.statusEnum {
        case .pending:  return .orange
        case .accepted: return Theme.Colors.success
        case .rejected: return Theme.Colors.tertiaryText
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(item.job.title)
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.primaryText)
                    if let address = item.job.addressDisplay {
                        Text(address)
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer()
                // Pay rate chip — primaryText (black/white)
                Text("$\(item.job.payRate)/hr")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.primaryText)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.primaryText.opacity(0.08))
                    .clipShape(Capsule())
            }

            HStack(spacing: Theme.Spacing.md) {
                Label(Self.df.string(from: item.job.scheduledStart), systemImage: "clock")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
                // Distance badge — hidden if null per spec
                if let dist = item.job.formattedDistance {
                    DistanceBadge(formatted: dist)
                }
            }

            // Application status badge
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(statusLabel)
                    .font(Theme.Typography.subheadline.weight(.medium))
                    .foregroundColor(statusColor)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .shadow(color: Theme.Shadows.small.color,
                radius: Theme.Shadows.small.radius, x: 0, y: Theme.Shadows.small.y)
    }
}

// MARK: - Completed Worker Card (worker tab 2)

struct CompletedWorkerCard: View {
    let item: MyApplicationItem

    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(item.job.title)
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.primaryText)
                    if let address = item.job.addressDisplay {
                        Text(address)
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer()
                // Pay rate chip — primaryText (black/white)
                Text("$\(item.job.payRate)/hr")
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundColor(Theme.Colors.primaryText)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.primaryText.opacity(0.08))
                    .clipShape(Capsule())
            }

            HStack(spacing: Theme.Spacing.md) {
                Label(Self.df.string(from: item.job.scheduledStart), systemImage: "clock")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
                // Distance badge — hidden if null per spec
                if let dist = item.job.formattedDistance {
                    DistanceBadge(formatted: dist)
                }
                Spacer()
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Colors.success)
                        .font(.system(size: Theme.Sizes.iconSmall))
                    Text("Completed")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.success)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .shadow(color: Theme.Shadows.small.color,
                radius: Theme.Shadows.small.radius, x: 0, y: Theme.Shadows.small.y)
    }
}

// MARK: - Completed Business Card (business tab 2)

struct CompletedBusinessCard: View {
    let job: APIJob

    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()

    private var earnings: String? {
        guard let end = job.scheduledEnd,
              let rate = Double(job.payRate) else { return nil }
        let hours = max(0, end.timeIntervalSince(job.scheduledStart) / 3600)
        guard hours > 0 else { return nil }
        return String(format: "$%.2f paid", hours * rate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(job.title)
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.primaryText)
                    if let address = job.addressDisplay {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text(address)
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.secondaryText)
                                .lineLimit(1)
                            
                            // Privacy indicator for approximate locations
                            if job.locationIsApproximate == true {
                                Image(systemName: "location.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.tertiaryText)
                            }
                        }
                    }
                }
                Spacer()
                if let paid = earnings {
                    Text(paid)
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.primaryText)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.primaryText.opacity(0.08))
                        .clipShape(Capsule())
                } else {
                    Text("$\(job.payRate)/hr")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.primaryText)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.primaryText.opacity(0.08))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: Theme.Spacing.md) {
                Label(Self.df.string(from: job.scheduledStart), systemImage: "clock")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
                if let dist = job.formattedDistance {
                    DistanceBadge(formatted: dist)
                }
                Spacer()
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Colors.success)
                        .font(.system(size: Theme.Sizes.iconSmall))
                    Text("Completed")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.success)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .shadow(color: Theme.Shadows.small.color,
                radius: Theme.Shadows.small.radius, x: 0, y: Theme.Shadows.small.y)
    }
}

#Preview {
    ShiftsView()
}

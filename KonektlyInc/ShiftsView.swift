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
            .task {
                // Tab 0 data — re-use cached if already loaded
                if jobStore.nearbyJobs.isEmpty && !jobStore.isLoadingNearbyJobs {
                    locationManager.requestAuthorization()
                    if let coord = await locationManager.currentCoordinate() {
                        await jobStore.fetchNearbyJobs(lat: coord.latitude, lng: coord.longitude)
                    }
                }
                // Worker: pre-fetch applications so tabs 1 & 2 are ready
                if userRole == .worker &&
                   jobStore.activeApplications.isEmpty &&
                   !jobStore.isLoadingMyApplications {
                    await jobStore.fetchMyApplications()
                }
            }
            // Refresh applications when switching to worker tabs 1 or 2
            .onChange(of: selectedTab) { _, tab in
                if userRole == .worker && (tab == 1 || tab == 2) {
                    Task { await jobStore.fetchMyApplications() }
                }
            }
        }
    }

    // MARK: - Tab 0: Available / Open

    @ViewBuilder
    private var availableTab: some View {
        if jobStore.isLoadingNearbyJobs {
            loadingView("Loading jobs…")
        } else if let error = jobStore.nearbyJobsError {
            errorView(error.errorDescription ?? "Failed to load jobs") {
                Task {
                    if let coord = await locationManager.currentCoordinate() {
                        await jobStore.fetchNearbyJobs(lat: coord.latitude, lng: coord.longitude)
                    }
                }
            }
        } else if userRole == .worker {
            if filteredNearbyJobs.isEmpty {
                emptyView("briefcase",
                          searchText.isEmpty ? "No jobs nearby right now" : "No results for \"\(searchText)\"")
            } else {
                ForEach(filteredNearbyJobs) { job in NearbyJobListCard(job: job) }
            }
        } else {
            // Business
            if openPostedJobs.isEmpty {
                emptyView("plus.square.dashed", "No open jobs — tap Post a Job to get started")
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
                Task { await jobStore.fetchMyApplications() }
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
        if activePostedJobs.isEmpty {
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

// MARK: - Nearby Job List Card (worker tab 0)

struct NearbyJobListCard: View {
    let job: APIJob
    @EnvironmentObject private var jobStore: JobStore

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
                        Label(address, systemImage: "mappin.and.ellipse")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("$\(job.payRate)/hr")
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.accent)
            }

            HStack(spacing: Theme.Spacing.md) {
                Label(Self.df.string(from: job.scheduledStart), systemImage: "clock")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
                if let km = job.distanceKm {
                    Label(String(format: "%.1f km", km), systemImage: "location")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
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

            if let applyError = jobStore.applyError,
               jobStore.lastSubmittedApplication != nil {
                Text(applyError.errorDescription ?? "")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.error)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .shadow(color: Theme.Shadows.small.color,
                radius: Theme.Shadows.small.radius, x: 0, y: Theme.Shadows.small.y)
    }

    private var alreadyApplied: Bool {
        jobStore.applyError == .alreadyApplied
    }
    private var jobFilled: Bool {
        job.statusEnum == .filled || job.statusEnum == .cancelled
    }
    private var applyButtonDisabled: Bool {
        jobStore.isApplying || alreadyApplied || jobFilled
    }
    private var applyButtonTitle: String {
        if alreadyApplied { return "Applied ✓" }
        if jobFilled       { return "Position Filled" }
        return "Apply Now"
    }
}

// MARK: - Posted Job List Card (business tab 0 & 1)

struct PostedJobListCard: View {
    let job: APIJob

    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()

    private var statusColor: Color {
        switch job.statusEnum {
        case .open:      return .green
        case .filled:    return Theme.Colors.accent
        case .cancelled: return Theme.Colors.error
        case .completed: return Theme.Colors.tertiaryText
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(job.title)
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.primaryText)
                    if let address = job.addressDisplay {
                        Label(address, systemImage: "mappin.and.ellipse")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                    Text("$\(job.payRate)/hr")
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.accent)
                    Text(job.status.capitalized)
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            Label(Self.df.string(from: job.scheduledStart), systemImage: "clock")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.tertiaryText)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .shadow(color: Theme.Shadows.small.color,
                radius: Theme.Shadows.small.radius, x: 0, y: Theme.Shadows.small.y)
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
        case .accepted: return "Hired ✓"
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
                        Label(address, systemImage: "mappin.and.ellipse")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("$\(item.job.payRate)/hr")
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.accent)
            }

            Label(Self.df.string(from: item.job.scheduledStart), systemImage: "clock")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.tertiaryText)

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
                        Label(address, systemImage: "mappin.and.ellipse")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("$\(item.job.payRate)/hr")
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.accent)
            }

            HStack(spacing: Theme.Spacing.md) {
                Label(Self.df.string(from: item.job.scheduledStart), systemImage: "clock")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
                Spacer()
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Colors.success)
                        .font(.system(size: Theme.Sizes.iconSmall))
                    Text("Completed")
                        .font(Theme.Typography.subheadline.weight(.medium))
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
                        Label(address, systemImage: "mappin.and.ellipse")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if let paid = earnings {
                    Text(paid)
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.accent)
                }
            }

            HStack(spacing: Theme.Spacing.md) {
                Label(Self.df.string(from: job.scheduledStart), systemImage: "clock")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
                Spacer()
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Colors.success)
                        .font(.system(size: Theme.Sizes.iconSmall))
                    Text("Completed")
                        .font(Theme.Typography.subheadline.weight(.medium))
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

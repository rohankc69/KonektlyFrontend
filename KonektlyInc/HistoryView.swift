//
//  HistoryView.swift
//  KonektlyInc
//

import SwiftUI

// MARK: - History Hub

struct HistoryView: View {
    @StateObject private var store = ActivityStore.shared
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            if let stats = store.stats {
                StatsBanner(stats: stats)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.sm)
            }

            Picker("", selection: $selectedTab) {
                Text("Feed").tag(0)
                Text("Jobs").tag(1)
                Text("Payments").tag(2)
                Text("Reviews").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)

            Divider()

            switch selectedTab {
            case 0: FeedTabView(store: store)
            case 1: JobsTabView(store: store)
            case 2: PaymentsTabView(store: store)
            default: ReviewsTabView(store: store)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await store.loadStats() }
                group.addTask { await store.loadFeed(reset: true) }
            }
        }
    }
}

// MARK: - Stats Banner

private struct StatsBanner: View {
    let stats: ActivityStats

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.md) {
                if let w = stats.worker {
                    StatCard(icon: "checkmark.circle.fill",
                             color: Theme.Colors.success,
                             value: "\(w.jobsCompleted)",
                             label: "Shifts Done")
                    StatCard(icon: "dollarsign.circle.fill",
                             color: Theme.Colors.accent,
                             value: formatCents(w.totalEarnedCents),
                             label: "Earned")
                    StatCard(icon: "star.fill",
                             color: .orange,
                             value: String(format: "%.1f", w.avgRating),
                             label: "Worker Rating")
                    StatCard(icon: "paperplane.fill",
                             color: Theme.Colors.secondaryText,
                             value: "\(w.applicationsSent)",
                             label: "Applied")
                }
                if let b = stats.business {
                    StatCard(icon: "briefcase.fill",
                             color: Theme.Colors.accent,
                             value: "\(b.jobsPosted)",
                             label: "Jobs Posted")
                    StatCard(icon: "dollarsign.circle.fill",
                             color: Theme.Colors.error,
                             value: formatCents(b.totalSpentCents),
                             label: "Spent")
                    StatCard(icon: "star.fill",
                             color: .orange,
                             value: String(format: "%.1f", b.avgRating),
                             label: "Business Rating")
                    StatCard(icon: "person.fill.checkmark",
                             color: Theme.Colors.success,
                             value: "\(b.workersHired)",
                             label: "Workers Hired")
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    private func formatCents(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        if dollars >= 1_000 {
            return String(format: "$%.0fk", dollars / 1_000)
        }
        return String(format: "$%.0f", dollars)
    }
}

private struct StatCard: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(Theme.Typography.headlineBold)
                .foregroundColor(Theme.Colors.primaryText)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(width: 80)
        .padding(.vertical, Theme.Spacing.md)
        .padding(.horizontal, Theme.Spacing.sm)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }
}

// MARK: - Feed Tab

private struct FeedTabView: View {
    @ObservedObject var store: ActivityStore

    var body: some View {
        Group {
            if store.isFeedLoading && store.feedEvents.isEmpty {
                HistoryLoadingView()
            } else if store.feedEvents.isEmpty {
                HistoryEmptyView(icon: "clock.arrow.circlepath",
                                 message: "No activity yet.\nYour timeline will appear here.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedFeedEvents, id: \.0) { day, events in
                            DayHeaderView(date: day)
                            ForEach(events) { event in
                                FeedEventRow(event: event)
                                Divider().padding(.leading, 60)
                            }
                        }
                        if store.feedHasNext {
                            LoadMoreButton(isLoading: store.isFeedLoading) {
                                Task { await store.loadFeed() }
                            }
                            .padding(Theme.Spacing.lg)
                        }
                    }
                }
                .refreshable { await store.loadFeed(reset: true) }
            }
        }
    }

    private var groupedFeedEvents: [(String, [ActivityEvent])] {
        let cal = Calendar.current
        var grouped: [(String, [ActivityEvent])] = []
        var seenKeys: [String] = []
        for event in store.feedEvents {
            let key = dayKey(event.timestamp, cal: cal)
            if let idx = grouped.firstIndex(where: { $0.0 == key }) {
                grouped[idx].1.append(event)
            } else {
                seenKeys.append(key)
                grouped.append((key, [event]))
            }
        }
        return grouped
    }

    private func dayKey(_ date: Date, cal: Calendar) -> String {
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let df = DateFormatter()
        df.dateFormat = "MMMM d"
        return df.string(from: date)
    }
}

private struct DayHeaderView: View {
    let date: String
    var body: some View {
        HStack {
            Text(date)
                .font(Theme.Typography.footnote.weight(.semibold))
                .foregroundColor(Theme.Colors.secondaryText)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.xs)
    }
}

private struct FeedEventRow: View {
    let event: ActivityEvent

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(Theme.Colors.primaryText)
                Text(event.subtitle)
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(timeText(event.timestamp))
                .font(Theme.Typography.caption2)
                .foregroundColor(Theme.Colors.tertiaryText)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }

    private var iconName: String {
        switch event.type {
        case "job_posted":             return "briefcase.fill"
        case "job_hired":              return "person.badge.plus"
        case "job_completed":          return "checkmark.circle.fill"
        case "job_cancelled":          return "xmark.circle.fill"
        case "job_applied":            return "paperplane.fill"
        case "application_rejected":   return "xmark.seal.fill"
        case "worker_hired":           return "person.fill.checkmark"
        case "payment_authorized":     return "creditcard.fill"
        case "payment_made":           return "dollarsign.circle.fill"
        case "payment_received":       return "arrow.down.circle.fill"
        case "payment_refunded":       return "arrow.uturn.left.circle.fill"
        case "payment_failed":         return "exclamationmark.circle.fill"
        case "review_given":           return "star.fill"
        case "review_received":        return "star.bubble.fill"
        case "subscription_upgraded":  return "crown.fill"
        default:                       return "circle.fill"
        }
    }

    private var iconColor: Color {
        switch event.type {
        case "job_posted", "job_hired", "job_applied", "worker_hired":
            return Theme.Colors.accent
        case "job_completed", "payment_received":
            return Theme.Colors.success
        case "job_cancelled", "application_rejected", "payment_failed":
            return Theme.Colors.error
        case "payment_authorized", "payment_made":
            return Theme.Colors.success
        case "payment_refunded":
            return Theme.Colors.warning
        case "review_given", "review_received":
            return .orange
        case "subscription_upgraded":
            return .purple
        default:
            return Theme.Colors.secondaryText
        }
    }

    private func timeText(_ date: Date) -> String {
        let df = DateFormatter()
        df.timeStyle = .short
        return df.string(from: date)
    }
}

// MARK: - Jobs Tab

private struct JobsTabView: View {
    @ObservedObject var store: ActivityStore
    @State private var roleFilter = ""

    var body: some View {
        VStack(spacing: 0) {
            ActivityFilterChipBar(
                options: [("", "All"), ("worker", "As Worker"), ("business", "As Business")],
                selected: $roleFilter
            )
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)

            Divider()

            Group {
                if store.isJobsLoading && store.jobs.isEmpty {
                    HistoryLoadingView()
                } else if store.jobs.isEmpty {
                    HistoryEmptyView(icon: "briefcase",
                                     message: "No job history yet.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            ForEach(store.jobs) { job in
                                ActivityJobRow(job: job)
                            }
                            if store.jobsHasNext {
                                LoadMoreButton(isLoading: store.isJobsLoading) {
                                    Task { await store.loadJobs(role: roleFilter) }
                                }
                            }
                        }
                        .padding(Theme.Spacing.lg)
                    }
                    .refreshable { await store.loadJobs(role: roleFilter, reset: true) }
                }
            }
        }
        .onChange(of: roleFilter) { _, newRole in
            Task { await store.loadJobs(role: newRole, reset: true) }
        }
        .onAppear {
            if store.jobs.isEmpty {
                Task { await store.loadJobs(role: roleFilter, reset: true) }
            }
        }
    }
}

private struct ActivityJobRow: View {
    let job: ActivityJob

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                RolePill(role: job.role)
                Spacer()
                StatusBadge(status: job.status)
            }

            Text(job.title)
                .font(Theme.Typography.bodySemibold)
                .foregroundColor(Theme.Colors.primaryText)

            HStack(spacing: Theme.Spacing.lg) {
                Label("$\(job.payRate)/hr", systemImage: "dollarsign.circle")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.secondaryText)

                if let addr = job.addressDisplay, !addr.isEmpty {
                    Label(addr, systemImage: "mappin")
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .lineLimit(1)
                }
            }

            if let date = job.displayDate {
                Label(formattedDate(date), systemImage: "calendar")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}

private struct RolePill: View {
    let role: String
    var body: some View {
        Text(role == "business" ? "Business" : "Worker")
            .font(Theme.Typography.caption.weight(.semibold))
            .foregroundColor(role == "business" ? Theme.Colors.accent : Theme.Colors.success)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 3)
            .background((role == "business" ? Theme.Colors.accent : Theme.Colors.success).opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct StatusBadge: View {
    let status: String
    var body: some View {
        Text(displayStatus)
            .font(Theme.Typography.caption.weight(.semibold))
            .foregroundColor(statusColor)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var displayStatus: String {
        switch status {
        case "open":      return "Open"
        case "filled":    return "Active"
        case "completed": return "Completed"
        case "cancelled": return "Cancelled"
        case "scheduled": return "Scheduled"
        default:          return status.capitalized
        }
    }

    private var statusColor: Color {
        switch status {
        case "open":      return Theme.Colors.accent
        case "filled", "scheduled": return Theme.Colors.warning
        case "completed": return Theme.Colors.success
        case "cancelled": return Theme.Colors.error
        default:          return Theme.Colors.secondaryText
        }
    }
}

// MARK: - Payments Tab

private struct PaymentsTabView: View {
    @ObservedObject var store: ActivityStore

    var body: some View {
        Group {
            if store.isPaymentsLoading && store.payments.isEmpty {
                HistoryLoadingView()
            } else if store.payments.isEmpty {
                HistoryEmptyView(icon: "creditcard",
                                 message: "No payment history yet.")
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(store.payments) { payment in
                            ActivityPaymentRow(payment: payment)
                        }
                        if store.paymentsHasNext {
                            LoadMoreButton(isLoading: store.isPaymentsLoading) {
                                Task { await store.loadPayments() }
                            }
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
                .refreshable { await store.loadPayments(reset: true) }
            }
        }
        .onAppear {
            if store.payments.isEmpty {
                Task { await store.loadPayments(reset: true) }
            }
        }
    }
}

private struct ActivityPaymentRow: View {
    let payment: ActivityPayment

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(amountColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: amountIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(amountColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(payment.jobTitle)
                    .font(Theme.Typography.bodySemibold)
                    .foregroundColor(Theme.Colors.primaryText)
                    .lineLimit(1)
                HStack(spacing: Theme.Spacing.sm) {
                    PaymentStatusBadge(status: payment.status)
                    RolePill(role: payment.role)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 3) {
                Text(formattedAmount)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundColor(amountColor)
                if let date = payment.displayDate {
                    Text(shortDate(date))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    private var formattedAmount: String {
        let dollars = Double(payment.displayAmountCents) / 100.0
        let prefix = payment.role == "worker" ? "+" : ""
        return "\(prefix)$\(String(format: "%.2f", dollars))"
    }

    private var amountColor: Color {
        switch payment.status {
        case "failed":   return Theme.Colors.error
        case "refunded": return Theme.Colors.warning
        default:         return payment.role == "worker" ? Theme.Colors.success : Theme.Colors.primaryText
        }
    }

    private var amountIcon: String {
        switch payment.status {
        case "failed":   return "exclamationmark.circle.fill"
        case "refunded": return "arrow.uturn.left.circle.fill"
        default:         return payment.role == "worker" ? "arrow.down.circle.fill" : "dollarsign.circle.fill"
        }
    }

    private func shortDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }
}

private struct PaymentStatusBadge: View {
    let status: String
    var body: some View {
        Text(displayStatus)
            .font(Theme.Typography.caption.weight(.semibold))
            .foregroundColor(statusColor)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var displayStatus: String {
        switch status {
        case "authorized": return "Authorized"
        case "captured":   return "Captured"
        case "transferred": return "Transferred"
        case "paid_out":   return "Paid Out"
        case "refunded":   return "Refunded"
        case "failed":     return "Failed"
        default:           return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private var statusColor: Color {
        switch status {
        case "authorized", "captured", "transferred": return Theme.Colors.accent
        case "paid_out":   return Theme.Colors.success
        case "refunded":   return Theme.Colors.warning
        case "failed":     return Theme.Colors.error
        default:           return Theme.Colors.secondaryText
        }
    }
}

// MARK: - Reviews Tab

private struct ReviewsTabView: View {
    @ObservedObject var store: ActivityStore
    @State private var directionFilter = ""

    var body: some View {
        VStack(spacing: 0) {
            ActivityFilterChipBar(
                options: [("", "All"), ("received", "Received"), ("given", "Given")],
                selected: $directionFilter
            )
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)

            Divider()

            Group {
                if store.isReviewsLoading && store.reviews.isEmpty {
                    HistoryLoadingView()
                } else if store.reviews.isEmpty {
                    HistoryEmptyView(icon: "star",
                                     message: "No reviews yet.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            ForEach(store.reviews) { review in
                                ActivityReviewRow(review: review)
                            }
                            if store.reviewsHasNext {
                                LoadMoreButton(isLoading: store.isReviewsLoading) {
                                    Task { await store.loadReviews(direction: directionFilter) }
                                }
                            }
                        }
                        .padding(Theme.Spacing.lg)
                    }
                    .refreshable { await store.loadReviews(direction: directionFilter, reset: true) }
                }
            }
        }
        .onChange(of: directionFilter) { _, newDir in
            Task { await store.loadReviews(direction: newDir, reset: true) }
        }
        .onAppear {
            if store.reviews.isEmpty {
                Task { await store.loadReviews(direction: directionFilter, reset: true) }
            }
        }
    }
}

private struct ActivityReviewRow: View {
    let review: ActivityReview

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                DirectionPill(direction: review.direction)
                Spacer()
                ActivityStarRating(rating: review.rating)
            }

            Text(review.jobTitle)
                .font(Theme.Typography.bodySemibold)
                .foregroundColor(Theme.Colors.primaryText)
                .lineLimit(1)

            if let name = review.otherPersonName, !name.isEmpty {
                Label(name, systemImage: "person.fill")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.secondaryText)
            }

            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .lineLimit(3)
                    .padding(.top, 2)
            }

            Text(formattedDate(review.createdAt))
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.tertiaryText)
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: date)
    }
}

private struct DirectionPill: View {
    let direction: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: direction == "given" ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 11))
            Text(direction == "given" ? "You Reviewed" : "Received")
                .font(Theme.Typography.caption.weight(.semibold))
        }
        .foregroundColor(direction == "given" ? Theme.Colors.accent : .orange)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 3)
        .background((direction == "given" ? Theme.Colors.accent : Color.orange).opacity(0.12))
        .clipShape(Capsule())
    }
}

private struct ActivityStarRating: View {
    let rating: Int
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: 12))
                    .foregroundColor(star <= rating ? .orange : Theme.Colors.tertiaryText)
            }
        }
    }
}

// MARK: - Shared Components

private struct ActivityFilterChipBar: View {
    let options: [(String, String)]   // (value, label)
    @Binding var selected: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(options, id: \.0) { value, label in
                    ActivityFilterChip(label: label, isSelected: selected == value) {
                        selected = value
                    }
                }
            }
        }
    }
}

private struct ActivityFilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.Typography.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Theme.Colors.buttonPrimary : Theme.Colors.secondaryText)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    isSelected
                        ? Theme.Colors.buttonPrimary.opacity(0.1)
                        : Theme.Colors.cardBackground
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            isSelected ? Theme.Colors.buttonPrimary : Theme.Colors.border,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct LoadMoreButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.85)
                } else {
                    Text("Load More")
                        .font(Theme.Typography.subheadline.weight(.semibold))
                }
            }
            .foregroundColor(Theme.Colors.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

private struct HistoryLoadingView: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)
            Spacer()
        }
    }
}

private struct HistoryEmptyView: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(Theme.Colors.tertiaryText)
            Text(message)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(Theme.Spacing.xl)
    }
}

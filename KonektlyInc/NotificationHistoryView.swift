//
//  NotificationHistoryView.swift
//  KonektlyInc
//
//  Inbox for campaign / marketing pushes (NotificationDelivery).
//

import SwiftUI

struct NotificationHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var items: [NotificationInboxItem] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var page = 1
    @State private var hasNext = false
    private let pageSize = 20

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.Colors.primaryText)
                        .frame(width: 40, height: 40)
                        .background(Theme.Colors.inputBackground)
                        .clipShape(Circle())
                }
                Spacer()
                Text("Notifications")
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)

            Divider()

            if isLoading && items.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if let err = errorMessage, items.isEmpty {
                Spacer()
                Text(err)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                Spacer()
            } else {
                List {
                    ForEach(items) { row in
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(row.titleRendered)
                                .font(Theme.Typography.bodyMedium)
                                .foregroundColor(Theme.Colors.primaryText)
                            Text(row.bodyRendered)
                                .font(Theme.Typography.subheadline)
                                .foregroundColor(Theme.Colors.secondaryText)
                            if let sent = row.sentAt {
                                Text(Self.format(sent))
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.tertiaryText)
                            }
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                    }
                    if hasNext {
                        Button {
                            Task { await loadMore() }
                        } label: {
                            HStack {
                                Spacer()
                                if isLoadingMore {
                                    ProgressView()
                                } else {
                                    Text("Load more")
                                        .font(Theme.Typography.subheadline.weight(.semibold))
                                }
                                Spacer()
                            }
                        }
                        .disabled(isLoadingMore)
                    }
                }
                .listStyle(.plain)
                .refreshable { await loadFirstPage() }
            }
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
        .task { await loadFirstPage() }
    }

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static func format(_ d: Date) -> String { Self.df.string(from: d) }

    private func loadFirstPage() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let env: NotificationHistoryEnvelope = try await APIClient.shared.request(
                .notificationHistory(page: 1, pageSize: pageSize)
            )
            items = env.notifications
            hasNext = env.hasNext
            page = env.page
        } catch {
            errorMessage = "Could not load notifications."
        }
    }

    private func loadMore() async {
        guard hasNext, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let nextPage = page + 1
        do {
            let env: NotificationHistoryEnvelope = try await APIClient.shared.request(
                .notificationHistory(page: nextPage, pageSize: pageSize)
            )
            items.append(contentsOf: env.notifications)
            hasNext = env.hasNext
            page = env.page
        } catch {
            // Keep previous page; user can retry load more
        }
    }
}

#Preview {
    NotificationHistoryView()
}

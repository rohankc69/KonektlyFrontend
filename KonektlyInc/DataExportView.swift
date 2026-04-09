//
//  DataExportView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-25.
//

import SwiftUI

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var exportStatus: DataExportStatusResponse.DataExportInfo?
    @State private var isInitialLoading = true
    @State private var isRefreshing = false
    @State private var isRequesting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pollingTimedOut = false
    @State private var pollLoopTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
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

                Text("Export My Data")
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.primaryText)

                Spacer()

                Color.clear
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)

            Divider()

            Group {
                if isInitialLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.xxl) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Theme.Colors.accent)
                                .padding(.top, Theme.Spacing.xxl)

                            VStack(spacing: Theme.Spacing.md) {
                                Text("Your Data, Your Right")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(Theme.Colors.primaryText)

                                Text("Request a copy of all your personal data. This includes your profile, job history, messages, and more.")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, Theme.Spacing.xl)
                            }

                            if let export = exportStatus {
                                exportStatusCard(export)
                            } else {
                                noExportView
                            }

                            if let error = errorMessage {
                                Text(error)
                                    .font(Theme.Typography.footnote)
                                    .foregroundColor(Theme.Colors.error)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, Theme.Spacing.xl)
                            }

                            if let success = successMessage {
                                Text(success)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.success)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, Theme.Spacing.xl)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.bottom, Theme.Spacing.xxl)
                    }
                    .refreshable {
                        await refreshStatusOnly()
                    }
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
        .task {
            await loadInitialStatus()
            restartPollingIfNeeded()
        }
        .onDisappear {
            pollLoopTask?.cancel()
            pollLoopTask = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .dataExportReady)) { _ in
            Task { await refreshStatusOnly() }
        }
        .onChange(of: exportStatus?.status) { _, _ in
            restartPollingIfNeeded()
        }
        .onChange(of: exportStatus?.downloadUrl) { _, _ in
            restartPollingIfNeeded()
        }
    }

    /// Backend may use `preparing`, `queued`, etc. — keep polling while no download URL yet.
    private func restartPollingIfNeeded() {
        pollLoopTask?.cancel()
        pollLoopTask = nil
        pollingTimedOut = false
        guard Self.shouldPoll(export: exportStatus) else { return }
        startBoundedPolling()
    }

    // MARK: - No Export View

    private var noExportView: some View {
        Button(action: requestExport) {
            if isRequesting {
                ProgressView()
                    .tint(Theme.Colors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                Text("Request Data Export")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.Colors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
        .background(Theme.Colors.accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .disabled(isRequesting)
    }

    // MARK: - Export Status Card

    @ViewBuilder
    private func exportStatusCard(_ export: DataExportStatusResponse.DataExportInfo) -> some View {
        let display = Self.displayStatusKey(export.status)
        let hasDownload = Self.nonEmptyURL(export.downloadUrl)
        let iconKey = hasDownload ? "completed" : display

        VStack(spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.md) {
                statusIcon(for: iconKey)

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle(for: display, hasDownload: hasDownload))
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.primaryText)

                    Text(statusDescription(for: export, displayKey: display, hasDownload: hasDownload))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }

                Spacer()
            }

            // Show download whenever the API provides a URL (some backends keep status as "preparing").
            if hasDownload, let urlString = export.downloadUrl, let url = URL(string: urlString) {
                Link(destination: url) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 18))
                        Text("Download")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.Colors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                }

                if let expiresAt = export.downloadExpiresAt {
                    Text("Download expires \(formattedExpiry(expiresAt))")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }

            if Self.isInProgress(status: export.status, hasDownload: hasDownload) {
                if pollingTimedOut {
                    Text("This is taking longer than usual. Check your email for a link, or pull to refresh.")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Button {
                    Task { await refreshStatusOnly() }
                } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.85)
                        }
                        Text("Refresh status")
                            .font(Theme.Typography.subheadline.weight(.semibold))
                    }
                    .foregroundColor(Theme.Colors.accent)
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
            }
        }
        .padding(Theme.Spacing.xl)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    // MARK: - Helpers

    private func statusIcon(for displayKey: String) -> some View {
        Group {
            switch displayKey {
            case "completed":
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Theme.Colors.success)
            case "in_progress":
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 32))
                    .foregroundColor(Theme.Colors.accent)
            case "failed":
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Theme.Colors.error)
            case "expired":
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 32))
                    .foregroundColor(Theme.Colors.warning)
            default:
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 32))
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
    }

    private func statusTitle(for displayKey: String, hasDownload: Bool) -> String {
        if hasDownload { return "Export ready" }
        switch displayKey {
        case "completed": return "Export ready"
        case "in_progress": return "Preparing your export"
        case "failed": return "Export failed"
        case "expired": return "Export expired"
        default: return "Export status"
        }
    }

    private func statusDescription(
        for export: DataExportStatusResponse.DataExportInfo,
        displayKey: String,
        hasDownload: Bool
    ) -> String {
        if hasDownload {
            return "Your data export is ready to download."
        }
        switch displayKey {
        case "completed":
            return "Your data export is ready to download."
        case "in_progress":
            return "We’ll notify you when it’s ready. You can leave this screen — check your email too."
        case "failed":
            return "Something went wrong. Try requesting a new export in a few minutes."
        case "expired":
            return "This link has expired. Request a new export."
        default:
            return "Hang tight — we’re still preparing your file. Pull down to refresh."
        }
    }

    private func formattedExpiry(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else { return dateString }
            return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
        }
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Network

    private func loadInitialStatus() async {
        isInitialLoading = true
        defer { isInitialLoading = false }
        await fetchStatus()
    }

    /// Refresh without replacing the whole screen with a spinner (pull-to-refresh & push).
    private func refreshStatusOnly() async {
        guard !isInitialLoading else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await fetchStatus()
    }

    private func fetchStatus() async {
        do {
            let response: DataExportStatusResponse = try await APIClient.shared.request(.dataExportStatus)
            exportStatus = response.export
            errorMessage = nil
        } catch {
            exportStatus = nil
            errorMessage = "Could not load export status. Pull to try again."
            print("[DataExport] status error: \(error)")
        }
    }

    private func requestExport() {
        isRequesting = true
        errorMessage = nil
        successMessage = nil

        Task {
            defer { isRequesting = false }
            do {
                let _: DataExportResponse = try await APIClient.shared.request(.requestDataExport)
                successMessage = "Your export is being prepared. We’ll notify you when it’s ready."
                await fetchStatus()
            } catch AppError.rateLimited {
                errorMessage = "You can only request one export per 24 hours."
            } catch let appError as AppError {
                errorMessage = appError.errorDescription
            } catch {
                errorMessage = AppError.network(underlying: error).errorDescription
            }
        }
    }

    /// Poll periodically while pending/processing (stops when status changes or after ~2 min).
    private func startBoundedPolling() {
        pollLoopTask?.cancel()
        pollLoopTask = Task { @MainActor in
            for attempt in 0..<30 {
                if Task.isCancelled { return }
                // Avoid stacking with the fetch that just set status to pending.
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if Task.isCancelled { return }
                await refreshStatusOnly()
                if let ex = exportStatus, !Self.shouldPoll(export: ex) {
                    pollingTimedOut = false
                    return
                }
                if attempt == 29 {
                    pollingTimedOut = true
                }
            }
        }
    }

    // MARK: - Status normalization (backend variants)

    private static func nonEmptyURL(_ raw: String?) -> Bool {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return false
        }
        return URL(string: raw) != nil
    }

    /// Maps raw API status to a small set of UI keys.
    private static func displayStatusKey(_ raw: String) -> String {
        let s = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch s {
        case "completed", "complete", "ready", "success", "done", "available":
            return "completed"
        case "failed", "error", "failure":
            return "failed"
        case "expired":
            return "expired"
        case "pending", "processing", "preparing", "queued", "queue", "in_progress", "running",
             "working", "started", "in progress":
            return "in_progress"
        default:
            // Treat unknown values as in-flight so we never show an empty "stuck" state.
            return "in_progress"
        }
    }

    private static func isInProgress(status: String, hasDownload: Bool) -> Bool {
        if hasDownload { return false }
        let d = displayStatusKey(status)
        if d == "failed" || d == "expired" { return false }
        if d == "completed" { return false }
        return true
    }

    private static func shouldPoll(export: DataExportStatusResponse.DataExportInfo?) -> Bool {
        guard let export else { return false }
        return isInProgress(status: export.status, hasDownload: nonEmptyURL(export.downloadUrl))
    }
}

#Preview {
    DataExportView()
}

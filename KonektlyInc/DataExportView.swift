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
    @State private var isLoading = true
    @State private var isRequesting = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

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

            ScrollView {
                VStack(spacing: Theme.Spacing.xxl) {
                    // Icon
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

                    if isLoading {
                        ProgressView()
                    } else if let export = exportStatus {
                        exportStatusCard(export)
                    } else {
                        // No active export
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
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
        .task { await checkStatus() }
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
        VStack(spacing: Theme.Spacing.lg) {
            HStack(spacing: Theme.Spacing.md) {
                statusIcon(for: export.status)

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle(for: export.status))
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.primaryText)

                    Text(statusDescription(for: export))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }

                Spacer()
            }

            if export.status == "completed", let urlString = export.downloadUrl,
               let url = URL(string: urlString) {
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

            if export.status == "pending" || export.status == "processing" {
                Button("Refresh Status") {
                    Task { await checkStatus() }
                }
                .font(Theme.Typography.subheadline.weight(.semibold))
                .foregroundColor(Theme.Colors.accent)
            }
        }
        .padding(Theme.Spacing.xl)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    // MARK: - Helpers

    private func statusIcon(for status: String) -> some View {
        Group {
            switch status {
            case "completed":
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(Theme.Colors.success)
            case "pending", "processing":
                ProgressView()
                    .scaleEffect(1.2)
                    .frame(width: 32, height: 32)
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

    private func statusTitle(for status: String) -> String {
        switch status {
        case "completed": return "Export Ready"
        case "pending": return "Preparing..."
        case "processing": return "Processing..."
        case "expired": return "Export Expired"
        default: return status.capitalized
        }
    }

    private func statusDescription(for export: DataExportStatusResponse.DataExportInfo) -> String {
        switch export.status {
        case "completed": return "Your data export is ready to download."
        case "pending", "processing": return "This may take a few minutes. Check back shortly."
        case "expired": return "This export has expired. Request a new one."
        default: return ""
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

    private func checkStatus() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: DataExportStatusResponse = try await APIClient.shared.request(.dataExportStatus)
            exportStatus = response.export
        } catch {
            // No active export — that's fine
            exportStatus = nil
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
                successMessage = "Your data export is being prepared. This may take a few minutes."
                // Refresh status
                await checkStatus()
            } catch AppError.rateLimited {
                errorMessage = "You can only request one export per 24 hours."
            } catch let appError as AppError {
                errorMessage = appError.errorDescription
            } catch {
                errorMessage = AppError.network(underlying: error).errorDescription
            }
        }
    }
}

#Preview {
    DataExportView()
}

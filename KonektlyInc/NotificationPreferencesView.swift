//
//  NotificationPreferencesView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-25.
//

import SwiftUI

struct NotificationPreferencesView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var jobNotifications = true
    @State private var messageNotifications = true
    @State private var marketingNotifications = true
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

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

                Text("Notifications")
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

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                List {
                    Section {
                        Toggle(isOn: $jobNotifications) {
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: "briefcase.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Theme.Colors.primaryText)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Job Notifications")
                                        .font(Theme.Typography.body)
                                        .foregroundColor(Theme.Colors.primaryText)
                                    Text("New job alerts near you")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.secondaryText)
                                }
                            }
                        }
                        .tint(Theme.Colors.accent)
                        .onChange(of: jobNotifications) { _, newValue in
                            save(update: NotificationPreferencesUpdate(jobNotifications: newValue))
                        }

                        Toggle(isOn: $messageNotifications) {
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: "bubble.left.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Theme.Colors.primaryText)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Message Notifications")
                                        .font(Theme.Typography.body)
                                        .foregroundColor(Theme.Colors.primaryText)
                                    Text("Chat message alerts")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.secondaryText)
                                }
                            }
                        }
                        .tint(Theme.Colors.accent)
                        .onChange(of: messageNotifications) { _, newValue in
                            save(update: NotificationPreferencesUpdate(messageNotifications: newValue))
                        }

                        Toggle(isOn: $marketingNotifications) {
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: "megaphone.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Theme.Colors.primaryText)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Marketing")
                                        .font(Theme.Typography.body)
                                        .foregroundColor(Theme.Colors.primaryText)
                                    Text("Promotional notifications")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.secondaryText)
                                }
                            }
                        }
                        .tint(Theme.Colors.accent)
                        .onChange(of: marketingNotifications) { _, newValue in
                            save(update: NotificationPreferencesUpdate(marketingNotifications: newValue))
                        }
                    } header: {
                        Text("Push Notifications")
                    } footer: {
                        Text("Control which notifications you receive. You can also manage notifications in your device's Settings app.")
                            .font(Theme.Typography.caption)
                    }

                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .font(Theme.Typography.footnote)
                                .foregroundColor(Theme.Colors.error)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
        .task { await fetchPreferences() }
    }

    private func fetchPreferences() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let prefs: NotificationPreferences = try await APIClient.shared.request(.notificationPreferences)
            jobNotifications = prefs.jobNotifications
            messageNotifications = prefs.messageNotifications
            marketingNotifications = prefs.marketingNotifications
        } catch {
            errorMessage = "Failed to load preferences."
        }
    }

    private func save(update: NotificationPreferencesUpdate) {
        errorMessage = nil
        Task {
            do {
                let _: NotificationPreferences = try await APIClient.shared.request(.updateNotificationPreferences(update))
            } catch {
                errorMessage = "Failed to update. Please try again."
                // Revert by re-fetching
                await fetchPreferences()
            }
        }
    }
}

#Preview {
    NotificationPreferencesView()
}

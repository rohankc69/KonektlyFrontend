//
//  NotificationPreferencesView.swift
//  KonektlyInc
//
//  Messaging toggles: GET/PATCH …/messages/notification-preferences/
//  Campaign / push caps: GET/PATCH …/notifications/preferences/
//

import SwiftUI

struct NotificationPreferencesView: View {
    @Environment(\.dismiss) private var dismiss

    // Messaging (jobs, chat, legacy marketing channel)
    @State private var jobNotifications = true
    @State private var messageNotifications = true
    @State private var marketingNotifications = true

    // Push notification engine (UserNotificationPreference)
    @State private var pushEnabled = true
    @State private var campaignMarketingEnabled = true
    @State private var quietHoursEnabled = false
    @State private var quietStartText = "22:00"
    @State private var quietEndText = "08:00"

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var pushPrefsError: String?
    @State private var showHistory = false

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
                            label(icon: "briefcase.fill", title: "Job alerts", subtitle: "New jobs near you")
                        }
                        .tint(Theme.Colors.accent)
                        .onChange(of: jobNotifications) { _, newValue in
                            saveMessaging(update: NotificationPreferencesUpdate(jobNotifications: newValue))
                        }

                        Toggle(isOn: $messageNotifications) {
                            label(icon: "bubble.left.fill", title: "Messages", subtitle: "Chat message alerts")
                        }
                        .tint(Theme.Colors.accent)
                        .onChange(of: messageNotifications) { _, newValue in
                            saveMessaging(update: NotificationPreferencesUpdate(messageNotifications: newValue))
                        }

                        Toggle(isOn: $marketingNotifications) {
                            label(icon: "megaphone.fill", title: "Offers channel", subtitle: "Legacy promotional channel")
                        }
                        .tint(Theme.Colors.accent)
                        .onChange(of: marketingNotifications) { _, newValue in
                            saveMessaging(update: NotificationPreferencesUpdate(marketingNotifications: newValue))
                        }
                    } header: {
                        Text("Jobs & messages")
                    } footer: {
                        Text("Controls job and chat alerts. Manage system alerts in the Settings app.")
                            .font(Theme.Typography.caption)
                    }

                    Section {
                        Toggle(isOn: $pushEnabled) {
                            label(icon: "bell.badge.fill", title: "Push notifications", subtitle: "Master switch for campaign pushes")
                        }
                        .tint(Theme.Colors.accent)
                        .onChange(of: pushEnabled) { _, _ in savePushPrefs() }

                        Toggle(isOn: $campaignMarketingEnabled) {
                            label(icon: "sparkles", title: "Campaigns & tips", subtitle: "Personalized offers and updates")
                        }
                        .tint(Theme.Colors.accent)
                        .onChange(of: campaignMarketingEnabled) { _, _ in savePushPrefs() }

                        Toggle(isOn: $quietHoursEnabled) {
                            label(icon: "moon.fill", title: "Quiet hours", subtitle: "Reduce notifications at night")
                        }
                        .tint(Theme.Colors.accent)
                        .onChange(of: quietHoursEnabled) { _, _ in savePushPrefs() }

                        if quietHoursEnabled {
                            HStack {
                                Text("From")
                                    .font(Theme.Typography.body)
                                TextField("22:00", text: $quietStartText)
                                    .keyboardType(.numbersAndPunctuation)
                                    .textContentType(.none)
                                    .autocorrectionDisabled()
                                    .font(Theme.Typography.body)
                                    .padding(Theme.Spacing.sm)
                                    .background(Theme.Colors.inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                                Text("To")
                                    .font(Theme.Typography.body)
                                TextField("08:00", text: $quietEndText)
                                    .keyboardType(.numbersAndPunctuation)
                                    .autocorrectionDisabled()
                                    .font(Theme.Typography.body)
                                    .padding(Theme.Spacing.sm)
                                    .background(Theme.Colors.inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                            }
                            Button("Save quiet hours") {
                                savePushPrefs()
                            }
                            .font(Theme.Typography.subheadline.weight(.semibold))
                            .foregroundColor(Theme.Colors.accent)
                        }
                    } header: {
                        Text("Campaigns")
                    } footer: {
                        Group {
                            if let pushPrefsError {
                                Text(pushPrefsError)
                                    .foregroundColor(Theme.Colors.error)
                            } else {
                                Text("Frequency limits and quiet hours are applied on the server. [TEST] pushes are from admin tools.")
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }
                        }
                        .font(Theme.Typography.caption)
                    }

                    Section {
                        Button {
                            showHistory = true
                        } label: {
                            HStack {
                                Image(systemName: "tray.full.fill")
                                    .foregroundColor(Theme.Colors.accent)
                                Text("Notification history")
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color(UIColor.systemGray3))
                            }
                        }
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
                .disabled(isSaving)
            }
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showHistory) {
            NotificationHistoryView()
        }
        .task { await fetchAll() }
    }

    private func label(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Theme.Colors.primaryText)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
    }

    private func fetchAll() async {
        isLoading = true
        errorMessage = nil
        pushPrefsError = nil
        defer { isLoading = false }

        async let messaging: Result<NotificationPreferences, Error> = {
            do {
                let p: NotificationPreferences = try await APIClient.shared.request(.messagingNotificationPreferences)
                return .success(p)
            } catch {
                return .failure(error)
            }
        }()

        async let push: Result<PushNotificationPreferencesEnvelope, Error> = {
            do {
                let p: PushNotificationPreferencesEnvelope = try await APIClient.shared.request(.pushNotificationPreferences)
                return .success(p)
            } catch {
                return .failure(error)
            }
        }()

        let m = await messaging
        let p = await push

        switch m {
        case .success(let prefs):
            jobNotifications = prefs.jobNotifications
            messageNotifications = prefs.messageNotifications
            marketingNotifications = prefs.marketingNotifications
        case .failure:
            errorMessage = "Could not load job and message preferences."
        }

        switch p {
        case .success(let env):
            let prefs = env.preferences
            pushEnabled = prefs.pushEnabled
            campaignMarketingEnabled = prefs.marketingEnabled
            quietHoursEnabled = prefs.quietHoursEnabled
            quietStartText = Self.formatQuiet(prefs.quietStart) ?? "22:00"
            quietEndText = Self.formatQuiet(prefs.quietEnd) ?? "08:00"
        case .failure:
            pushPrefsError = "Campaign preferences are unavailable (update the app or try again later)."
        }
    }

    /// Backend sends "HH:MM:SS" or null — show HH:MM
    private static func formatQuiet(_ s: String?) -> String? {
        guard let s, !s.isEmpty else { return nil }
        let parts = s.split(separator: ":")
        if parts.count >= 2 {
            return "\(parts[0]):\(parts[1])"
        }
        return String(s)
    }

    /// Accepts "HH:MM" or "H:MM" → "HH:MM:SS"
    private static func normalizeTime(_ raw: String) -> String? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = t.split(separator: ":").map(String.init)
        guard parts.count >= 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]),
              h >= 0, h < 24, m >= 0, m < 60 else { return nil }
        return String(format: "%02d:%02d:00", h, m)
    }

    private func saveMessaging(update: NotificationPreferencesUpdate) {
        errorMessage = nil
        Task {
            do {
                let _: NotificationPreferences = try await APIClient.shared.request(
                    .updateMessagingNotificationPreferences(update)
                )
            } catch {
                errorMessage = "Could not update preferences."
                await fetchAll()
            }
        }
    }

    private func savePushPrefs() {
        pushPrefsError = nil
        Task {
            isSaving = true
            defer { isSaving = false }
            let qStart = quietHoursEnabled ? Self.normalizeTime(quietStartText) : nil
            let qEnd = quietHoursEnabled ? Self.normalizeTime(quietEndText) : nil
            if quietHoursEnabled && (qStart == nil || qEnd == nil) {
                pushPrefsError = "Enter quiet hours as 24h times, e.g. 22:00 and 08:00."
                return
            }
            var req = PushNotificationPreferencesUpdate(
                marketingEnabled: campaignMarketingEnabled,
                pushEnabled: pushEnabled,
                quietHoursEnabled: quietHoursEnabled,
                quietStart: quietHoursEnabled ? qStart : nil,
                quietEnd: quietHoursEnabled ? qEnd : nil
            )
            if !quietHoursEnabled {
                req.quietStart = nil
                req.quietEnd = nil
            }
            do {
                let env: PushNotificationPreferencesEnvelope = try await APIClient.shared.request(
                    .updatePushNotificationPreferences(req)
                )
                let prefs = env.preferences
                pushEnabled = prefs.pushEnabled
                campaignMarketingEnabled = prefs.marketingEnabled
                quietHoursEnabled = prefs.quietHoursEnabled
                quietStartText = Self.formatQuiet(prefs.quietStart) ?? quietStartText
                quietEndText = Self.formatQuiet(prefs.quietEnd) ?? quietEndText
            } catch {
                pushPrefsError = "Could not save campaign preferences."
                await fetchAll()
            }
        }
    }
}

#Preview {
    NotificationPreferencesView()
}

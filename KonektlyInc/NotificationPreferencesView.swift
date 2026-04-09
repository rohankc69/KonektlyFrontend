//
//  NotificationPreferencesView.swift
//  KonektlyInc
//
//  GET/PATCH /api/v1/notifications/preferences/ — unified preferences in `data.preferences`.
//

import SwiftUI

struct NotificationPreferencesView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var pushEnabled = true
    @State private var jobNotifications = true
    @State private var messageNotifications = true
    @State private var marketingEnabled = true
    @State private var quietHoursEnabled = false
    @State private var quietStartDate = Date()
    @State private var quietEndDate = Date()

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showHistory = false

    /// Avoid firing PATCH when applying server state to local `@State`.
    @State private var isApplyingRemote = false

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
                        toggleRow(
                            icon: "bell.badge.fill",
                            title: "All notifications",
                            subtitle: "Master switch for push alerts",
                            binding: pushBinding
                        )

                        toggleRow(
                            icon: "briefcase.fill",
                            title: "Job alerts",
                            subtitle: "Hired, new jobs nearby, rejected",
                            binding: jobBinding
                        )
                        .disabled(!pushEnabled)
                        .opacity(pushEnabled ? 1 : 0.45)

                        toggleRow(
                            icon: "bubble.left.fill",
                            title: "Chat messages",
                            subtitle: "New message alerts",
                            binding: messageBinding
                        )
                        .disabled(!pushEnabled)
                        .opacity(pushEnabled ? 1 : 0.45)

                        toggleRow(
                            icon: "megaphone.fill",
                            title: "Promotions & offers",
                            subtitle: "Marketing and campaigns",
                            binding: marketingBinding
                        )
                        .disabled(!pushEnabled)
                        .opacity(pushEnabled ? 1 : 0.45)
                    } header: {
                        Text("Preferences")
                    } footer: {
                        Text("Transactional updates (payments, support replies, reviews) are delivered when All notifications is on. Fine-grained toggles don’t apply to those.")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }

                    Section {
                        Toggle(isOn: quietHoursBinding) {
                            label(
                                icon: "moon.fill",
                                title: "Quiet hours",
                                subtitle: "Reduce non-urgent notifications during a window"
                            )
                        }
                        .tint(Theme.Colors.accent)
                        .disabled(!pushEnabled)
                        .opacity(pushEnabled ? 1 : 0.45)

                        if quietHoursEnabled && pushEnabled {
                            DatePicker(
                                "From",
                                selection: $quietStartDate,
                                displayedComponents: .hourAndMinute
                            )
                            .tint(Theme.Colors.accent)

                            DatePicker(
                                "To",
                                selection: $quietEndDate,
                                displayedComponents: .hourAndMinute
                            )
                            .tint(Theme.Colors.accent)

                            Button {
                                saveQuietTimes()
                            } label: {
                                Text("Save quiet hours")
                                    .font(Theme.Typography.subheadline.weight(.semibold))
                                    .foregroundColor(Theme.Colors.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Quiet hours")
                    } footer: {
                        Text("Times use 24-hour format and are sent to the server as HH:MM:SS (e.g. 22:00:00).")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
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

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
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
        .task { await loadPreferences() }
    }

    // MARK: - Toggle bindings (PATCH single field)

    private var pushBinding: Binding<Bool> {
        Binding(
            get: { pushEnabled },
            set: { new in
                pushEnabled = new
                guard !isApplyingRemote else { return }
                patch(PushNotificationPreferencesUpdate(pushEnabled: new))
            }
        )
    }

    private var jobBinding: Binding<Bool> {
        Binding(
            get: { jobNotifications },
            set: { new in
                jobNotifications = new
                guard !isApplyingRemote else { return }
                patch(PushNotificationPreferencesUpdate(jobNotifications: new))
            }
        )
    }

    private var messageBinding: Binding<Bool> {
        Binding(
            get: { messageNotifications },
            set: { new in
                messageNotifications = new
                guard !isApplyingRemote else { return }
                patch(PushNotificationPreferencesUpdate(messageNotifications: new))
            }
        )
    }

    private var marketingBinding: Binding<Bool> {
        Binding(
            get: { marketingEnabled },
            set: { new in
                marketingEnabled = new
                guard !isApplyingRemote else { return }
                patch(PushNotificationPreferencesUpdate(marketingEnabled: new))
            }
        )
    }

    private var quietHoursBinding: Binding<Bool> {
        Binding(
            get: { quietHoursEnabled },
            set: { new in
                quietHoursEnabled = new
                guard !isApplyingRemote else { return }
                if new {
                    patch(
                        PushNotificationPreferencesUpdate(
                            quietHoursEnabled: true,
                            quietStart: Self.hhmmss(from: quietStartDate),
                            quietEnd: Self.hhmmss(from: quietEndDate)
                        )
                    )
                } else {
                    patch(PushNotificationPreferencesUpdate(quietHoursEnabled: false))
                }
            }
        )
    }

    private func saveQuietTimes() {
        guard quietHoursEnabled, pushEnabled else { return }
        patch(
            PushNotificationPreferencesUpdate(
                quietStart: Self.hhmmss(from: quietStartDate),
                quietEnd: Self.hhmmss(from: quietEndDate)
            )
        )
    }

    private func toggleRow(
        icon: String,
        title: String,
        subtitle: String,
        binding: Binding<Bool>
    ) -> some View {
        Toggle(isOn: binding) {
            label(icon: icon, title: title, subtitle: subtitle)
        }
        .tint(Theme.Colors.accent)
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

    private func applyFromServer(_ prefs: PushNotificationPreferences) {
        isApplyingRemote = true
        pushEnabled = prefs.pushEnabled
        jobNotifications = prefs.jobNotifications
        messageNotifications = prefs.messageNotifications
        marketingEnabled = prefs.marketingEnabled
        quietHoursEnabled = prefs.quietHoursEnabled
        quietStartDate = Self.dateFromHHMMSS(prefs.quietStart, defaultHour: 22, defaultMinute: 0)
        quietEndDate = Self.dateFromHHMMSS(prefs.quietEnd, defaultHour: 8, defaultMinute: 0)
        isApplyingRemote = false
    }

    private func loadPreferences() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let env: PushNotificationPreferencesEnvelope = try await APIClient.shared.request(
                .pushNotificationPreferences
            )
            applyFromServer(env.preferences)
        } catch {
            errorMessage = "Could not load notification preferences."
            print("[NOTIFY_PREFS] load error: \(error)")
        }
    }

    private func patch(_ update: PushNotificationPreferencesUpdate) {
        errorMessage = nil
        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                let env: PushNotificationPreferencesEnvelope = try await APIClient.shared.request(
                    .updatePushNotificationPreferences(update)
                )
                applyFromServer(env.preferences)
            } catch {
                errorMessage = "Could not save preferences."
                print("[NOTIFY_PREFS] patch error: \(error)")
                await loadPreferences()
            }
        }
    }

    /// Backend: "HH:MM:SS" or null
    private static func hhmmss(from date: Date) -> String {
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        return String(format: "%02d:%02d:00", h, m)
    }

    private static func dateFromHHMMSS(_ s: String?, defaultHour: Int, defaultMinute: Int) -> Date {
        let cal = Calendar.current
        let base = Date()
        guard let s, !s.isEmpty else {
            return cal.date(bySettingHour: defaultHour, minute: defaultMinute, second: 0, of: base) ?? base
        }
        let parts = s.split(separator: ":")
        guard parts.count >= 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]),
              h >= 0, h < 24, m >= 0, m < 60
        else {
            return cal.date(bySettingHour: defaultHour, minute: defaultMinute, second: 0, of: base) ?? base
        }
        let sec = parts.count > 2 ? (Int(parts[2]) ?? 0) : 0
        return cal.date(bySettingHour: h, minute: m, second: min(59, max(0, sec)), of: base) ?? base
    }
}

#Preview {
    NotificationPreferencesView()
}

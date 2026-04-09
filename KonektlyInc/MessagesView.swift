//
//  MessagesView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct MessagesView: View {
    @EnvironmentObject private var messageStore: MessageStore
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()

    var filteredConversations: [APIConversation] {
        if searchText.isEmpty {
            return messageStore.conversations
        }
        return messageStore.conversations.filter {
            $0.otherUserName.localizedCaseInsensitiveContains(searchText) ||
            $0.jobTitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.Colors.secondaryText)
                        .font(.system(size: Theme.Sizes.iconMedium))

                    TextField("Search messages...", text: $searchText)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.Colors.secondaryText)
                                .font(.system(size: Theme.Sizes.iconMedium))
                        }
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.tertiaryBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .padding(Theme.Spacing.lg)

                // Conversations list
                if messageStore.isLoadingConversations && messageStore.conversations.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredConversations.isEmpty {
                    EmptyStateView(
                        icon: "bubble.left.and.bubble.right",
                        title: "No messages",
                        subtitle: searchText.isEmpty ? "Messages will appear here when you hire or get hired for a job" : "No results found"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredConversations) { conversation in
                                NavigationLink(value: conversation.id) {
                                    ConversationRow(conversation: conversation)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .padding(.leading, Theme.Sizes.avatarMedium + Theme.Spacing.lg * 2)
                            }
                        }
                    }
                    .refreshable {
                        await messageStore.loadConversations()
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: UUID.self) { conversationId in
                if let conversation = messageStore.conversations.first(where: { $0.id == conversationId }) {
                    ChatView(conversation: conversation)
                        .environmentObject(messageStore)
                }
            }
            .task {
                await messageStore.loadConversations()
            }
            .onChange(of: messageStore.pendingDeepLinkConversationId) { _, newId in
                guard let conversationId = newId else { return }
                messageStore.pendingDeepLinkConversationId = nil
                // Navigate to the chat
                navigationPath.append(conversationId)
            }
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: APIConversation

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Theme.Colors.tertiaryBackground)
                    .frame(width: Theme.Sizes.avatarMedium, height: Theme.Sizes.avatarMedium)

                Text(avatarInitials)
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.primaryText)
            }

            // Content
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text(conversation.otherUserName)
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.primaryText)
                        .lineLimit(1)

                    Spacer()

                    if let lastMsg = conversation.lastMessage {
                        Text(timeAgoString(from: lastMsg.createdAt))
                            .font(Theme.Typography.caption)
                            .foregroundColor(conversation.unreadCount > 0 ? Theme.Colors.accent : Theme.Colors.secondaryText)
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conversation.jobTitle)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .lineLimit(1)

                        if let lastMsg = conversation.lastMessage {
                            Text(lastMsg.body)
                                .font(Theme.Typography.body)
                                .foregroundColor(conversation.unreadCount > 0 ? Theme.Colors.primaryText : Theme.Colors.secondaryText)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }

                    Spacer()

                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(Theme.Typography.caption.weight(.bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .padding(.horizontal, Theme.Spacing.xs)
                            .background(Theme.Colors.accent)
                            .clipShape(Capsule())
                    }

                    if conversation.isMuted == true {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: Theme.Sizes.iconSmall))
                            .foregroundColor(Theme.Colors.secondaryText)
                    }

                    if conversation.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: Theme.Sizes.iconSmall))
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(conversation.unreadCount > 0 ? Theme.Colors.tertiaryBackground.opacity(0.3) : Color.clear)
    }

    private var avatarInitials: String {
        let parts = conversation.otherUserName.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }

    private func timeAgoString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)

        if let day = components.day, day > 0 {
            return "\(day)d"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m"
        } else {
            return "now"
        }
    }
}

// MARK: - Chat View

struct ChatView: View {
    let conversation: APIConversation
    @EnvironmentObject private var messageStore: MessageStore
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool

    // Report/Block state
    @State private var showReportSheet = false
    @State private var showBlockConfirmation = false
    @State private var reportReason = ""
    @State private var reportDetails = ""
    @State private var isSubmittingReport = false
    @State private var isBlocking = false
    @State private var showActionToast: String?
    @State private var showMuteOptions = false
    @State private var isMuted = false

    private var currentUserId: Int {
        authStore.currentUser?.id ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Locked banner
            if messageStore.currentConversationIsLocked {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: Theme.Sizes.iconSmall))
                    Text("Job completed — chat ended")
                        .font(Theme.Typography.subheadline)
                }
                .foregroundColor(Theme.Colors.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.tertiaryBackground)
            }

            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        // Load more button
                        if messageStore.hasMoreMessages {
                            Button {
                                Task { await messageStore.loadMoreMessages() }
                            } label: {
                                if messageStore.isLoadingMessages {
                                    ProgressView()
                                } else {
                                    Text("Load earlier messages")
                                        .font(Theme.Typography.subheadline)
                                        .foregroundColor(Theme.Colors.accent)
                                }
                            }
                            .padding(.top, Theme.Spacing.md)
                        }

                        ForEach(messageStore.currentMessages) { message in
                            MessageBubble(
                                message: message,
                                isFromCurrentUser: message.senderId == currentUserId,
                                onRetry: message.sendStatus == .failed ? {
                                    messageStore.retryMessage(message)
                                } : nil
                            )
                        }

                        // Invisible anchor for scroll-to-bottom
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(Theme.Spacing.lg)
                }
                .onChange(of: messageStore.currentMessages.count) { _, _ in
                    withAnimation(Theme.Animation.quick) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onAppear {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }

            Divider()

            // Input bar (hidden when locked)
            if !messageStore.currentConversationIsLocked {
                VStack(spacing: 0) {
                    // Character count warning
                    if messageText.count > MessageStore.maxMessageLength - 100 {
                        HStack {
                            Spacer()
                            Text("\(messageText.count)/\(MessageStore.maxMessageLength)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(messageText.count > MessageStore.maxMessageLength ? Theme.Colors.error : Theme.Colors.secondaryText)
                                .padding(.trailing, Theme.Spacing.lg)
                                .padding(.bottom, Theme.Spacing.xs)
                        }
                    }

                    HStack(spacing: Theme.Spacing.md) {
                        // Text field
                        HStack(spacing: Theme.Spacing.sm) {
                            TextField("Type a message...", text: $messageText)
                                .font(Theme.Typography.body)
                                .focused($isInputFocused)
                                .onChange(of: messageText) { _, newValue in
                                    if newValue.count > MessageStore.maxMessageLength {
                                        messageText = String(newValue.prefix(MessageStore.maxMessageLength))
                                    }
                                }

                            if !messageText.isEmpty {
                                Button(action: { messageText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Theme.Colors.tertiaryText)
                                }
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.tertiaryBackground)
                        .cornerRadius(Theme.CornerRadius.pill)

                        // Send button
                        Button(action: sendMessage) {
                            Image(systemName: messageText.isEmpty ? "arrow.up.circle" : "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(messageText.isEmpty ? Theme.Colors.tertiaryText : Theme.Colors.accent)
                        }
                        .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(Theme.Spacing.lg)
                }
                .background(Theme.Colors.background)
            }
        }
        .navigationTitle(conversation.otherUserName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: Theme.Spacing.md) {
                    // Mute bell icon
                    Button {
                        showMuteOptions = true
                    } label: {
                        Image(systemName: isMuted ? "bell.slash.fill" : "bell.fill")
                            .font(.system(size: 18))
                            .foregroundColor(isMuted ? Theme.Colors.secondaryText : Theme.Colors.primaryText)
                    }

                    Menu {
                        Button(role: .destructive) {
                            showReportSheet = true
                        } label: {
                            Label("Report", systemImage: "flag")
                        }

                        Button(role: .destructive) {
                            showBlockConfirmation = true
                        } label: {
                            Label("Block \(conversation.otherUserName.components(separatedBy: " ").first ?? "User")", systemImage: "hand.raised")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                }
            }
        }
        .confirmationDialog("Mute Notifications", isPresented: $showMuteOptions, titleVisibility: .visible) {
            if isMuted {
                Button("Unmute") { muteConversation(duration: nil, unmute: true) }
            } else {
                Button("Mute for 1 hour") { muteConversation(duration: 3600) }
                Button("Mute for 8 hours") { muteConversation(duration: 28800) }
                Button("Mute forever") { muteConversation(duration: nil, unmute: false) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            isMuted = conversation.isMuted ?? false
            await messageStore.enterChat(conversationId: conversation.id)
        }
        .onDisappear {
            messageStore.leaveChat()
            Task {
                await messageStore.loadConversations()
                await messageStore.loadUnreadCount()
            }
        }
        // Report sheet
        .sheet(isPresented: $showReportSheet) {
            ReportSheet(
                userName: conversation.otherUserName,
                reason: $reportReason,
                details: $reportDetails,
                isSubmitting: isSubmittingReport,
                onSubmit: submitReport,
                onCancel: { showReportSheet = false }
            )
            .presentationDetents([.height(560), .large])
            .presentationDragIndicator(.hidden)
        }
        // Block confirmation
        .alert("Block \(conversation.otherUserName)?", isPresented: $showBlockConfirmation) {
            Button("Block", role: .destructive) { blockUser() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't be able to send you messages. You can unblock them later in Settings.")
        }
        // Toast overlay
        .overlay(alignment: .top) {
            if let toast = showActionToast {
                Text(toast)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(.white)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.buttonPrimary.opacity(0.9))
                    .cornerRadius(Theme.CornerRadius.medium)
                    .padding(.top, Theme.Spacing.lg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { showActionToast = nil }
                        }
                    }
            }
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageStore.sendMessage(text)
        messageText = ""

        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    private func submitReport() {
        guard !reportReason.isEmpty else { return }
        isSubmittingReport = true
        Task {
            do {
                try await messageStore.reportConversation(
                    conversationId: conversation.id,
                    reason: reportReason,
                    details: reportDetails.isEmpty ? nil : reportDetails
                )
                showReportSheet = false
                reportReason = ""
                reportDetails = ""
                withAnimation { showActionToast = "Report submitted. We'll review it shortly." }
            } catch {
                print("[MSG] Report failed: \(error)")
            }
            isSubmittingReport = false
        }
    }

    private func muteConversation(duration: TimeInterval?, unmute: Bool = false) {
        Task {
            do {
                if unmute {
                    let _: VoidAPIResponse = try await APIClient.shared.request(
                        .unmuteConversation(conversationId: conversation.id))
                    isMuted = false
                    withAnimation { showActionToast = "Notifications unmuted" }
                } else {
                    var mutedUntil: String? = nil
                    if let duration {
                        let date = Date().addingTimeInterval(duration)
                        mutedUntil = ISO8601DateFormatter().string(from: date)
                    }
                    let _: VoidAPIResponse = try await APIClient.shared.request(
                        .muteConversation(conversationId: conversation.id, mutedUntil: mutedUntil))
                    isMuted = true
                    if let duration {
                        let hours = Int(duration / 3600)
                        withAnimation { showActionToast = "Muted for \(hours) hour\(hours == 1 ? "" : "s")" }
                    } else {
                        withAnimation { showActionToast = "Notifications muted" }
                    }
                }
            } catch {
                withAnimation { showActionToast = "Failed to update mute setting" }
            }
        }
    }

    private func blockUser() {
        guard let userId = Int(conversation.otherUserId) else {
            print("[MSG] Block failed: otherUserId '\(conversation.otherUserId)' is not a valid integer")
            withAnimation { showActionToast = "Could not identify user to block" }
            return
        }
        isBlocking = true
        Task {
            do {
                try await messageStore.blockUser(userId: userId)
                withAnimation { showActionToast = "\(conversation.otherUserName) blocked" }
                // Go back to conversations since this chat is now hidden
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    dismiss()
                }
            } catch {
                print("[MSG] Block failed: \(error)")
                let msg = (error as? AppError)?.errorDescription ?? "Failed to block user"
                withAnimation { showActionToast = msg }
            }
            isBlocking = false
        }
    }
}

// MARK: - Report Sheet

struct ReportSheet: View {
    let userName: String
    @Binding var reason: String
    @Binding var details: String
    let isSubmitting: Bool
    let onSubmit: () -> Void
    let onCancel: () -> Void

    private let reasons = [
        ("spam",          "Spam"),
        ("harassment",    "Harassment or bullying"),
        ("inappropriate", "Inappropriate content"),
        ("scam",          "Scam or fraud"),
        ("other",         "Other")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color(UIColor.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 4)

            // Header row — Cancel | Report | Submit
            HStack {
                Button("Cancel", action: onCancel)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)

                Spacer()

                Text("Report")
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.primaryText)

                Spacer()

                Button(action: onSubmit) {
                    if isSubmitting {
                        ProgressView().scaleEffect(0.85)
                    } else {
                        Text("Submit")
                            .font(Theme.Typography.body.weight(.semibold))
                            .foregroundColor(
                                reason.isEmpty
                                    ? Theme.Colors.tertiaryText
                                    : Theme.Colors.accent
                            )
                    }
                }
                .disabled(reason.isEmpty || isSubmitting)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Subtitle
                    Text("Why are you reporting \(userName)?")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .padding(.top, Theme.Spacing.sm)

                    // Reason options
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(reasons, id: \.0) { value, label in
                            Button {
                                reason = value
                            } label: {
                                HStack(spacing: Theme.Spacing.md) {
                                    Text(label)
                                        .font(Theme.Typography.body)
                                        .foregroundColor(Theme.Colors.primaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Image(systemName: reason == value
                                          ? "checkmark.circle.fill"
                                          : "circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(
                                            reason == value
                                                ? Theme.Colors.accent
                                                : Theme.Colors.tertiaryText
                                        )
                                }
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, 14)
                                .background(Theme.Colors.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Optional details
                    TextField("Additional details (optional)", text: $details, axis: .vertical)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                        .lineLimit(3...5)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .background(Theme.Colors.background)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: DisplayMessage
    let isFromCurrentUser: Bool
    var onRetry: (() -> Void)?

    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: Theme.Spacing.xs) {
                Text(message.body)
                    .font(Theme.Typography.body)
                    .foregroundColor(isFromCurrentUser ? .white : Theme.Colors.primaryText)
                    .padding(Theme.Spacing.md)
                    .background(isFromCurrentUser ? Theme.Colors.accent : Theme.Colors.tertiaryBackground)
                    .cornerRadius(Theme.CornerRadius.large)

                HStack(spacing: Theme.Spacing.xs) {
                    Text(formatTimestamp(message.createdAt))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)

                    if isFromCurrentUser {
                        switch message.sendStatus {
                        case .pending:
                            ProgressView()
                                .scaleEffect(0.6)
                        case .delivered:
                            if message.isRead {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.accent)
                            } else {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.Colors.tertiaryText)
                            }
                        case .failed:
                            Button {
                                onRetry?()
                            } label: {
                                HStack(spacing: 2) {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.system(size: 12))
                                    Text("Tap to retry")
                                        .font(Theme.Typography.caption)
                                }
                                .foregroundColor(Theme.Colors.error)
                            }
                        }
                    }
                }
            }

            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.tertiaryText)

            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.primary)

                Text(subtitle)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.tertiaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xxxl)
    }
}

#Preview {
    NavigationStack {
        MessagesView()
            .environmentObject(MessageStore.shared)
    }
}

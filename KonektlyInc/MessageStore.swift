//
//  MessageStore.swift
//  KonektlyInc
//
//  Central state manager for messaging. Manages conversations list,
//  current chat messages, unread counts, and real-time WebSocket integration.
//

import Foundation
import Combine

// MARK: - Message Send Status

enum MessageSendStatus: Equatable {
    case pending
    case delivered
    case failed
}

// MARK: - Display Message (wraps APIChatMessage with send status)

struct DisplayMessage: Identifiable, Equatable {
    let id: UUID
    let conversationId: UUID
    let senderId: Int
    let senderName: String
    let body: String
    var isRead: Bool
    let createdAt: Date
    var sendStatus: MessageSendStatus

    init(from apiMessage: APIChatMessage) {
        self.id = apiMessage.id
        self.conversationId = apiMessage.conversation
        self.senderId = apiMessage.sender
        self.senderName = apiMessage.senderName
        self.body = apiMessage.body
        self.isRead = apiMessage.isRead
        self.createdAt = apiMessage.createdAt
        self.sendStatus = .delivered
    }

    init(pending body: String, conversationId: UUID, senderId: Int, senderName: String) {
        self.id = UUID()
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.body = body
        self.isRead = true
        self.createdAt = Date()
        self.sendStatus = .pending
    }
}

// MARK: - Message Store

@MainActor
final class MessageStore: ObservableObject {
    static let shared = MessageStore()
    private init() {}

    /// Maximum message body length allowed by the backend
    static let maxMessageLength = 2000

    // MARK: Published State

    @Published var conversations: [APIConversation] = []
    @Published var isLoadingConversations = false

    @Published var currentMessages: [DisplayMessage] = []
    @Published var isLoadingMessages = false
    @Published var hasMoreMessages = false
    @Published var currentConversationIsLocked = false

    @Published var totalUnreadCount: Int = 0

    /// Set by AppDelegate when user taps a push notification. Observed by MessagesView for deep-link navigation.
    @Published var pendingDeepLinkConversationId: UUID?

    // MARK: Private State

    private let wsManager = ChatWebSocketManager()
    private(set) var currentConversationId: UUID?
    private var ackTimeoutTasks: [UUID: Task<Void, Never>] = [:]

    /// Maps temp client UUID → pending message index for correct ack matching on rapid sends.
    /// Acks arrive in send order, so we use a FIFO queue.
    private var pendingMessageQueue: [UUID] = []

    private let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Fallback formatter without fractional seconds
    private let iso8601FallbackFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parseDate(_ str: String) -> Date {
        iso8601Formatter.date(from: str) ?? iso8601FallbackFormatter.date(from: str) ?? Date()
    }

    // MARK: - Conversations List

    func loadConversations() async {
        isLoadingConversations = true
        defer { isLoadingConversations = false }

        do {
            let response: ConversationsListResponse = try await APIClient.shared.request(.conversations)
            conversations = response.conversations
        } catch {
            print("[MSG] loadConversations failed: \(error)")
        }
    }

    // MARK: - Unread Count

    func loadUnreadCount() async {
        do {
            let response: UnreadCountResponse = try await APIClient.shared.request(.unreadCount)
            totalUnreadCount = response.unreadCount
        } catch {
            print("[MSG] loadUnreadCount failed: \(error)")
        }
    }

    // MARK: - Enter/Leave Chat

    func enterChat(conversationId: UUID) async {
        currentConversationId = conversationId
        currentMessages = []
        hasMoreMessages = false
        currentConversationIsLocked = false
        pendingMessageQueue = []

        // Load history via REST first
        await loadMessages(conversationId: conversationId)

        // Connect WebSocket with last message ID for missed message recovery
        wsManager.delegate = self
        let lastId = currentMessages.last?.id
        wsManager.connect(conversationId: conversationId, lastMessageId: lastId)

        // Note: read receipt and REST reconciliation now happen in webSocketDidConnect
        // after the WS handshake is confirmed, not prematurely.
    }

    func leaveChat() {
        wsManager.disconnect()
        wsManager.delegate = nil
        currentConversationId = nil
        currentMessages = []
        pendingMessageQueue = []
        ackTimeoutTasks.values.forEach { $0.cancel() }
        ackTimeoutTasks.removeAll()
    }

    /// Called when app returns to foreground — reconnects WebSocket if user is in a chat
    func reconnectIfNeeded() {
        guard let conversationId = currentConversationId else { return }
        let lastId = currentMessages.last?.id
        wsManager.delegate = self
        wsManager.connect(conversationId: conversationId, lastMessageId: lastId)
    }

    // MARK: - Load Messages (REST)

    private func loadMessages(conversationId: UUID, before: UUID? = nil) async {
        isLoadingMessages = true
        defer { isLoadingMessages = false }

        do {
            let response: ConversationMessagesResponse = try await APIClient.shared.request(
                .conversationMessages(conversationId: conversationId, before: before)
            )
            currentConversationIsLocked = response.isLocked
            hasMoreMessages = response.hasMore

            let newMessages = response.messages.map { DisplayMessage(from: $0) }
            if before != nil {
                // Prepend older messages (load more)
                currentMessages.insert(contentsOf: newMessages, at: 0)
            } else {
                // Preserve local unconfirmed messages so they don't disappear
                // while waiting for WS ack/retry reconciliation.
                let localUnconfirmed = currentMessages.filter { $0.sendStatus != .delivered }
                var merged = newMessages
                let existingIds = Set(newMessages.map { $0.id })
                for local in localUnconfirmed where !existingIds.contains(local.id) {
                    merged.append(local)
                }
                merged.sort { $0.createdAt < $1.createdAt }
                currentMessages = merged
            }
        } catch {
            print("[MSG] loadMessages failed: \(error)")
        }
    }

    func loadMoreMessages() async {
        guard let conversationId = currentConversationId,
              let oldestMessage = currentMessages.first,
              hasMoreMessages else { return }
        await loadMessages(conversationId: conversationId, before: oldestMessage.id)
    }

    // MARK: - Send Message

    func sendMessage(_ body: String) {
        guard let conversationId = currentConversationId else { return }
        guard !currentConversationIsLocked else { return }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Enforce max message length
        let clampedBody = String(trimmed.prefix(Self.maxMessageLength))

        let currentUserId = AuthStore.shared.currentUser?.id ?? 0
        let currentUserName = [
            AuthStore.shared.currentUser?.firstName,
            AuthStore.shared.currentUser?.lastName
        ].compactMap { $0 }.joined(separator: " ")

        let pendingMessage = DisplayMessage(
            pending: clampedBody,
            conversationId: conversationId,
            senderId: currentUserId,
            senderName: currentUserName.isEmpty ? "You" : currentUserName
        )

        currentMessages.append(pendingMessage)
        pendingMessageQueue.append(pendingMessage.id)
        wsManager.sendMessage(body: clampedBody)

        // Ack timeout — mark as failed after 8 seconds (gives reconnect time)
        startAckTimeout(for: pendingMessage.id)
    }

    // MARK: - Retry Failed Message

    func retryMessage(_ message: DisplayMessage) {
        guard !currentConversationIsLocked else { return }
        guard let idx = currentMessages.firstIndex(where: { $0.id == message.id }) else { return }
        currentMessages[idx].sendStatus = .pending
        pendingMessageQueue.append(message.id)
        wsManager.sendMessage(body: message.body)
        startAckTimeout(for: message.id)
    }

    // MARK: - Ack Timeout

    private func startAckTimeout(for msgId: UUID) {
        ackTimeoutTasks[msgId]?.cancel()
        ackTimeoutTasks[msgId] = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard !Task.isCancelled else { return }
            if let idx = self.currentMessages.firstIndex(where: { $0.id == msgId && $0.sendStatus == .pending }) {
                self.currentMessages[idx].sendStatus = .failed
            }
            self.pendingMessageQueue.removeAll { $0 == msgId }
            self.ackTimeoutTasks.removeValue(forKey: msgId)
        }
    }

    // MARK: - Resend Pending Messages

    /// Called after WS reconnects — resends any messages still in pending/failed state
    private func resendUndeliveredMessages() {
        for i in currentMessages.indices {
            let msg = currentMessages[i]
            guard msg.sendStatus == .pending || msg.sendStatus == .failed else { continue }
            guard msg.senderId == (AuthStore.shared.currentUser?.id ?? 0) else { continue }

            currentMessages[i].sendStatus = .pending
            if !pendingMessageQueue.contains(msg.id) {
                pendingMessageQueue.append(msg.id)
            }
            wsManager.sendMessage(body: msg.body)
            startAckTimeout(for: msg.id)
        }
    }

    // MARK: - Mark As Read

    func markAsRead(upTo messageId: UUID) {
        wsManager.sendReadReceipt(lastReadId: messageId)
    }

    // MARK: - Device Registration

    func registerDevice(token: String) async {
        let req = DeviceRegisterRequest(token: token, platform: "ios")
        do {
            let _: DeviceRegisterResponse = try await APIClient.shared.request(.registerDevice(req))
            print("[MSG] Device registered for push")
        } catch {
            print("[MSG] Device registration failed: \(error)")
        }
    }

    func unregisterDevice(token: String) async {
        let req = DeviceUnregisterRequest(token: token)
        do {
            let _: VoidAPIResponse = try await APIClient.shared.request(.unregisterDevice(req))
            print("[MSG] Device unregistered")
        } catch {
            print("[MSG] Device unregister failed: \(error)")
        }
    }

    // MARK: - Start Conversation (Pre-Hire Chat)

    func startConversation(applicationId: Int) async throws -> UUID {
        let req = StartConversationRequest(applicationId: applicationId)
        let response: StartConversationResponse = try await APIClient.shared.request(.startConversation(req))
        // Refresh conversations so the new chat appears in the list
        await loadConversations()
        return response.conversationId
    }

    // MARK: - Block / Report

    func blockUser(userId: Int) async throws {
        let _: BlockUserResponse = try await APIClient.shared.request(.blockUser(userId: userId))
        // Refresh conversations — blocked user's conversations will be hidden by backend
        await loadConversations()
    }

    func unblockUser(userId: Int) async throws {
        let _: VoidAPIResponse = try await APIClient.shared.request(.unblockUser(userId: userId))
    }

    func loadBlockedUsers() async throws -> [BlockedUser] {
        let response: BlockedUsersResponse = try await APIClient.shared.request(.blockedUsers)
        return response.blockedUsers
    }

    func reportConversation(conversationId: UUID, reason: String, messageId: UUID? = nil, details: String? = nil) async throws {
        let req = ReportRequest(reason: reason, messageId: messageId?.uuidString.lowercased(), details: details)
        let _: ReportResponse = try await APIClient.shared.request(.reportConversation(conversationId: conversationId, req))
    }

    // MARK: - Clear State (on logout)

    func clearAll() {
        leaveChat()
        conversations = []
        totalUnreadCount = 0
        isLoadingConversations = false
        pendingDeepLinkConversationId = nil
    }
}

// MARK: - ChatWebSocketDelegate

extension MessageStore: ChatWebSocketDelegate {
    func webSocketDidConnect() {
        print("[MSG] WebSocket connected (handshake confirmed)")
        // Reconcile delivery state after confirmed connect by refetching latest history.
        if let conversationId = currentConversationId {
            Task {
                await loadMessages(conversationId: conversationId)

                // Mark messages as read now that we have a live connection
                if let lastMsg = currentMessages.last {
                    wsManager.sendReadReceipt(lastReadId: lastMsg.id)
                }

                // Resend any pending/failed messages through the now-confirmed connection
                resendUndeliveredMessages()
            }
        }
    }

    func webSocketDidDisconnect(code: URLSessionWebSocketTask.CloseCode?) {
        print("[MSG] WebSocket disconnected, code: \(String(describing: code))")
    }

    func webSocketSendDidFail(body: String) {
        // Find the pending message with this body and mark it failed immediately
        // so the user sees "tap to retry" right away instead of waiting for timeout.
        if let idx = currentMessages.lastIndex(where: { $0.body == body && $0.sendStatus == .pending }) {
            let msgId = currentMessages[idx].id
            currentMessages[idx].sendStatus = .failed
            pendingMessageQueue.removeAll { $0 == msgId }
            ackTimeoutTasks[msgId]?.cancel()
            ackTimeoutTasks.removeValue(forKey: msgId)
        }
    }

    func webSocketDidReceive(_ incoming: WSIncoming) {
        switch incoming {

        case .status(let isLocked, _, let message):
            currentConversationIsLocked = isLocked
            if isLocked {
                print("[MSG] Chat locked: \(message ?? "Job completed")")
            }

        case .message(let messageId, let senderId, let senderName, let body, let createdAtStr):
            guard let msgUUID = UUID(uuidString: messageId) else { return }

            // Skip if we already have this message
            guard !currentMessages.contains(where: { $0.id == msgUUID }) else { return }

            let createdAt = parseDate(createdAtStr)
            let senderIdInt = Int(senderId) ?? 0

            let msg = DisplayMessage(
                from: APIChatMessage(
                    id: msgUUID,
                    conversation: currentConversationId ?? UUID(),
                    sender: senderIdInt,
                    senderName: senderName,
                    body: body,
                    isRead: false,
                    createdAt: createdAt
                )
            )

            // Insert sorted by createdAt
            if let insertIndex = currentMessages.firstIndex(where: { $0.createdAt > createdAt }) {
                currentMessages.insert(msg, at: insertIndex)
            } else {
                currentMessages.append(msg)
            }

            wsManager.trackMessageId(msgUUID)

            // Auto-mark as read if we're viewing this chat
            if currentConversationId != nil {
                wsManager.sendReadReceipt(lastReadId: msgUUID)
            }

            // Update conversations list
            Task {
                await loadConversations()
                await loadUnreadCount()
            }

        case .ack(let messageId, let createdAtStr):
            guard let msgUUID = UUID(uuidString: messageId) else { return }
            let serverDate = parseDate(createdAtStr)

            // Use FIFO queue to match ack to the correct pending message
            guard let tempId = pendingMessageQueue.first else { return }
            pendingMessageQueue.removeFirst()

            // Cancel timeout for the temp ID
            ackTimeoutTasks[tempId]?.cancel()
            ackTimeoutTasks.removeValue(forKey: tempId)

            // Find the pending message by its temp ID and replace with server-confirmed version
            if let idx = currentMessages.firstIndex(where: { $0.id == tempId }) {
                let old = currentMessages[idx]
                let confirmed = DisplayMessage(
                    from: APIChatMessage(
                        id: msgUUID,
                        conversation: old.conversationId,
                        sender: old.senderId,
                        senderName: old.senderName,
                        body: old.body,
                        isRead: old.isRead,
                        createdAt: serverDate
                    )
                )
                currentMessages[idx] = confirmed
                wsManager.trackMessageId(msgUUID)
            }

            // Refresh conversations to update last message preview
            Task {
                await loadConversations()
            }

        case .readReceipt(_, let lastReadIdStr):
            guard let lastReadUUID = UUID(uuidString: lastReadIdStr) else { return }
            let currentUserId = AuthStore.shared.currentUser?.id ?? 0

            // Mark all our sent messages up to lastReadId as read
            for i in currentMessages.indices {
                if currentMessages[i].senderId == currentUserId && !currentMessages[i].isRead {
                    currentMessages[i].isRead = true
                }
                if currentMessages[i].id == lastReadUUID { break }
            }

        case .error(let code, let message):
            print("[MSG] WS error: \(code) — \(message)")
            if code == "CHAT_LOCKED" {
                currentConversationIsLocked = true
            }
        }
    }
}

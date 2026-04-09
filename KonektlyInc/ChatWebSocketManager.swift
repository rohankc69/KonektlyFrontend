//
//  ChatWebSocketManager.swift
//  KonektlyInc
//
//  Real-time WebSocket manager for chat messaging.
//  Handles connection, reconnection with exponential backoff,
//  sending/receiving messages, read receipts, and missed message recovery.
//

import Foundation

// MARK: - WebSocket Incoming Message Types

enum WSIncoming {
    case status(isLocked: Bool, conversationId: String?, message: String?)
    case message(messageId: String, senderId: String, senderName: String, body: String, createdAt: String)
    case ack(messageId: String, createdAt: String)
    case readReceipt(readerId: String, lastReadId: String)
    case error(code: String, message: String)
}

// MARK: - WebSocket Delegate

@MainActor
protocol ChatWebSocketDelegate: AnyObject {
    func webSocketDidReceive(_ incoming: WSIncoming)
    func webSocketDidConnect()
    func webSocketDidDisconnect(code: URLSessionWebSocketTask.CloseCode?)
    func webSocketSendDidFail(body: String)
}

// MARK: - ChatWebSocketManager

@MainActor
final class ChatWebSocketManager {
    weak var delegate: ChatWebSocketDelegate?

    private var webSocketTask: URLSessionWebSocketTask?
    private var reconnectAttempt = 0
    private let maxReconnectDelay: TimeInterval = 30
    private var lastMessageId: UUID?
    private var conversationId: UUID?
    private var isIntentionalDisconnect = false
    private var reconnectTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var hasReceivedFirstMessage = false

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        return URLSession(configuration: config)
    }()

    /// Whether the WebSocket has completed handshake and is ready to send
    private(set) var isConnected = false

    // MARK: - Connect

    func connect(conversationId: UUID, lastMessageId: UUID? = nil) {
        self.conversationId = conversationId
        self.lastMessageId = lastMessageId
        self.isIntentionalDisconnect = false
        reconnectAttempt = 0

        // Always force-refresh the access token before the initial connect.
        // bootstrapTokensIfNeeded skips if token is already in-memory, but an
        // in-memory token may be expired — clearing it first forces a real refresh
        // and avoids the 4001 → refresh → reconnect round-trip.
        reconnectTask?.cancel()
        reconnectTask = Task { @MainActor [weak self] in
            TokenStore.shared.accessToken = nil
            await APIClient.shared.bootstrapTokensIfNeeded()
            guard !Task.isCancelled, let self, !self.isIntentionalDisconnect else { return }
            self.doConnect()
        }
    }

    private func doConnect() {
        guard let conversationId else { return }

        guard let accessToken = TokenStore.shared.accessToken else {
            print("[WS] Still no access token after refresh, cannot connect")
            return
        }

        pingTask?.cancel()
        pingTask = nil

        // Cancel existing task
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        isConnected = false
        hasReceivedFirstMessage = false

        let conversationIdPath = conversationId.uuidString.lowercased()
        guard var components = URLComponents(url: Config.wsBaseURL, resolvingAgainstBaseURL: false) else {
            print("[WS] Invalid wsBaseURL: \(Config.wsBaseURL.absoluteString)")
            return
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + [basePath, "ws", "chat", conversationIdPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/") + "/"
        var items: [URLQueryItem] = [URLQueryItem(name: "token", value: accessToken)]
        if let lastId = lastMessageId {
            items.append(URLQueryItem(name: "last_message_id", value: lastId.uuidString.lowercased()))
        }
        components.queryItems = items

        guard let url = components.url else {
            print("[WS] Could not build websocket URL")
            return
        }

        print("[WS] Connecting to \(url.absoluteString.prefix(80))...")
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveMessage()
        // NOTE: Do NOT call delegate?.webSocketDidConnect() here.
        // It will be called when we receive the first successful message from the server,
        // confirming the handshake is actually complete.
    }

    // MARK: - Disconnect

    func disconnect() {
        isIntentionalDisconnect = true
        isConnected = false
        hasReceivedFirstMessage = false
        pingTask?.cancel()
        pingTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        print("[WS] Disconnected intentionally")
    }

    // MARK: - Send Message

    func sendMessage(body: String) {
        let payload: [String: Any] = [
            "type": "message",
            "body": body
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        // Only fail immediately if there's no task at all (fully disconnected).
        // URLSessionWebSocketTask queues sends during handshake, so sending
        // before isConnected is fine — the ack timeout handles true failures.
        guard let task = webSocketTask else {
            print("[WS] Cannot send — no WebSocket task")
            delegate?.webSocketSendDidFail(body: body)
            return
        }

        task.send(.string(jsonString)) { [weak self] error in
            if let error {
                print("[WS] Send error: \(error)")
                Task { @MainActor [weak self] in
                    self?.delegate?.webSocketSendDidFail(body: body)
                }
            }
        }
    }

    // MARK: - Send Read Receipt

    func sendReadReceipt(lastReadId: UUID) {
        let payload: [String: Any] = [
            "type": "read",
            "last_read_id": lastReadId.uuidString.lowercased()
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8) else { return }

        webSocketTask?.send(.string(jsonString)) { error in
            if let error {
                print("[WS] Read receipt send error: \(error)")
            }
        }
    }

    // MARK: - Track Last Message ID

    func trackMessageId(_ id: UUID) {
        lastMessageId = id
    }

    // MARK: - Receive Loop

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            Task { @MainActor [self] in
                switch result {
                case .success(let message):
                    // First successful receive confirms the WS handshake is complete
                    if !self.hasReceivedFirstMessage {
                        self.hasReceivedFirstMessage = true
                        self.isConnected = true
                        self.reconnectAttempt = 0
                        self.startPingKeepalive()
                        self.delegate?.webSocketDidConnect()
                    }

                    switch message {
                    case .string(let text):
                        self.handleIncomingText(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleIncomingText(text)
                        }
                    @unknown default:
                        break
                    }
                    self.receiveMessage() // Continue listening
                case .failure(let error):
                    print("[WS] Receive error: \(error)")
                    self.isConnected = false
                    self.handleDisconnect(error: error)
                }
            }
        }
    }

    // MARK: - ALB / proxy idle timeout (~60s): RFC 6455 ping frames keep the connection warm.

    private func startPingKeepalive() {
        pingTask?.cancel()
        pingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 25_000_000_000)
                guard !Task.isCancelled, let self, self.isConnected, let task = self.webSocketTask else { continue }
                task.sendPing { err in
                    if let err { print("[WS] ping failed: \(err)") }
                }
            }
        }
    }

    /// Coerce JSON values Django may send as string, int, or number.
    private func coercedString(_ value: Any?) -> String {
        if let s = value as? String { return s }
        if let i = value as? Int { return String(i) }
        if let n = value as? NSNumber { return n.stringValue }
        return ""
    }

    // MARK: - Parse Incoming

    private func handleIncomingText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            print("[WS] Unparseable message: \(text.prefix(200))")
            return
        }

        let incoming: WSIncoming
        switch type {
        case "status":
            incoming = .status(
                isLocked: json["is_locked"] as? Bool ?? false,
                conversationId: json["conversation_id"] as? String,
                message: json["message"] as? String
            )
        case "message":
            let senderIdString: String = {
                if let str = json["sender_id"] as? String { return str }
                if let int = json["sender_id"] as? Int { return String(int) }
                if let num = json["sender_id"] as? NSNumber { return num.stringValue }
                return ""
            }()
            incoming = .message(
                messageId: coercedString(json["message_id"]),
                senderId: senderIdString,
                senderName: json["sender_name"] as? String ?? "",
                body: json["body"] as? String ?? "",
                createdAt: json["created_at"] as? String ?? ""
            )
        case "ack":
            incoming = .ack(
                messageId: coercedString(json["message_id"]),
                createdAt: json["created_at"] as? String ?? ""
            )
        case "read_receipt":
            let readerIdString: String = {
                if let str = json["reader_id"] as? String { return str }
                if let int = json["reader_id"] as? Int { return String(int) }
                if let num = json["reader_id"] as? NSNumber { return num.stringValue }
                return ""
            }()
            incoming = .readReceipt(
                readerId: readerIdString,
                lastReadId: coercedString(json["last_read_id"])
            )
        case "error":
            incoming = .error(
                code: json["code"] as? String ?? "UNKNOWN",
                message: json["message"] as? String ?? ""
            )
        default:
            print("[WS] Unknown message type: \(type)")
            return
        }

        delegate?.webSocketDidReceive(incoming)
    }

    // MARK: - Reconnection

    private func handleDisconnect(error: Error?) {
        let closeCode = webSocketTask?.closeCode

        delegate?.webSocketDidDisconnect(code: closeCode)

        guard !isIntentionalDisconnect else { return }

        // Check for custom close codes
        if let code = closeCode {
            let rawCode = code.rawValue
            print("[WS] Close code: \(rawCode)")

            // 4004 = not a participant — do NOT reconnect
            if rawCode == 4004 {
                print("[WS] Not a participant (4004), will not reconnect")
                return
            }

            // 4001 = auth expired — refresh token before reconnecting
            if rawCode == 4001 {
                print("[WS] Auth expired (4001), refreshing token...")
                reconnectTask = Task { @MainActor [weak self] in
                    // Force-clear so bootstrapTokensIfNeeded actually refreshes
                    TokenStore.shared.accessToken = nil
                    await APIClient.shared.bootstrapTokensIfNeeded()
                    guard !Task.isCancelled else { return }
                    guard let self, !self.isIntentionalDisconnect else { return }
                    self.reconnectAttempt = 0
                    self.doConnect()
                }
                return
            }
        }

        let delay = min(pow(2.0, Double(reconnectAttempt)), maxReconnectDelay)
        reconnectAttempt += 1
        print("[WS] Reconnecting in \(delay)s (attempt \(reconnectAttempt))...")

        reconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard let self, !self.isIntentionalDisconnect else { return }

            // Only force a token refresh every 3rd attempt to avoid hammering the
            // refresh endpoint on transient network drops. Auth-specific close codes
            // (4001) already handle eager refresh above.
            if self.reconnectAttempt % 3 == 0 {
                TokenStore.shared.accessToken = nil
                await APIClient.shared.bootstrapTokensIfNeeded()
            }

            self.doConnect()
        }
    }
}

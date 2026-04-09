//
//  SupportStore.swift
//  KonektlyInc
//

import Foundation
import Combine

@MainActor
final class SupportStore: ObservableObject {
    static let shared = SupportStore()
    private init() {}

    // MARK: - Ticket List

    @Published private(set) var tickets: [SupportTicket] = []
    @Published private(set) var isLoadingTickets = false
    @Published private(set) var ticketsError: SupportStoreError?

    // MARK: - Ticket Messages

    @Published private(set) var selectedMessages: [TicketMessage] = []
    @Published private(set) var isLoadingMessages = false
    @Published private(set) var isSendingMessage = false
    @Published private(set) var sendMessageError: SupportStoreError?
    @Published private(set) var isClosingTicket = false
    @Published private(set) var closeTicketError: SupportStoreError?

    // MARK: - Create Ticket

    @Published private(set) var isCreatingTicket = false
    @Published private(set) var createTicketError: SupportStoreError?

    // MARK: - FAQs

    @Published private(set) var faqs: [SupportFAQ] = []
    @Published private(set) var isLoadingFAQs = false

    // MARK: - Fetch Tickets

    func fetchTickets() async {
        guard !isLoadingTickets else { return }
        isLoadingTickets = true
        ticketsError = nil
        defer { isLoadingTickets = false }
        do {
            let resp: SupportTicketListResponse = try await APIClient.shared.request(.supportTickets)
            tickets = resp.tickets
        } catch {
            if !(error is CancellationError) {
                ticketsError = SupportStoreError.from(error as? AppError ?? .unknown)
            }
        }
    }

    // MARK: - Create Ticket

    @discardableResult
    func createTicket(subject: String, description: String, category: String) async -> SupportTicket? {
        guard !isCreatingTicket else { return nil }
        isCreatingTicket = true
        createTicketError = nil
        defer { isCreatingTicket = false }
        do {
            let req = CreateTicketRequest(
                subject: subject, description: description,
                category: category, priority: "medium"
            )
            let resp: SupportTicketDetailResponse = try await APIClient.shared.request(.createTicket(req))
            tickets.insert(resp.ticket, at: 0)
            return resp.ticket
        } catch {
            if !(error is CancellationError) {
                let appError = error as? AppError ?? .unknown
                print("[SUPPORT] createTicket failed: \(appError) — \(appError.errorDescription ?? "")")
                createTicketError = SupportStoreError.from(appError)
            }
            return nil
        }
    }

    // MARK: - Messages

    func fetchMessages(ticketNumber: String) async {
        guard !isLoadingMessages else { return }
        isLoadingMessages = true
        defer { isLoadingMessages = false }
        do {
            let resp: TicketMessageListResponse = try await APIClient.shared.request(
                .ticketMessages(ticketNumber: ticketNumber)
            )
            selectedMessages = resp.messages
        } catch {
            if !(error is CancellationError) {
                print("[SUPPORT] fetchMessages error: \(error)")
            }
        }
    }

    func clearMessages() {
        selectedMessages = []
        sendMessageError = nil
        closeTicketError = nil
    }

    @discardableResult
    func sendMessage(ticketNumber: String, message: String) async -> Bool {
        guard !isSendingMessage else { return false }
        isSendingMessage = true
        sendMessageError = nil
        defer { isSendingMessage = false }
        do {
            let resp: SingleTicketMessageResponse = try await APIClient.shared.request(
                .sendTicketMessage(ticketNumber: ticketNumber, message: message)
            )
            selectedMessages.append(resp.message)
            return true
        } catch {
            if !(error is CancellationError) {
                sendMessageError = SupportStoreError.from(error as? AppError ?? .unknown)
            }
            return false
        }
    }

    @discardableResult
    func closeTicket(ticketNumber: String) async -> Bool {
        guard !isClosingTicket else { return false }
        isClosingTicket = true
        closeTicketError = nil
        defer { isClosingTicket = false }
        do {
            let resp: SupportTicketDetailResponse = try await APIClient.shared.request(
                .closeTicket(ticketNumber: ticketNumber)
            )
            tickets = tickets.map { $0.ticketNumber == ticketNumber ? resp.ticket : $0 }
            return true
        } catch {
            if !(error is CancellationError) {
                closeTicketError = SupportStoreError.from(error as? AppError ?? .unknown)
            }
            return false
        }
    }

    // MARK: - FAQs

    func fetchFAQs() async {
        guard !isLoadingFAQs else { return }
        isLoadingFAQs = true
        defer { isLoadingFAQs = false }
        do {
            let resp: FAQListResponse = try await APIClient.shared.request(.supportFAQs)
            faqs = resp.faqs
        } catch {
            if !(error is CancellationError) {
                print("[SUPPORT] fetchFAQs error: \(error)")
            }
        }
    }

    func voteFAQ(id: Int, isHelpful: Bool) async {
        do {
            let resp: FAQVoteResponse = try await APIClient.shared.request(.faqVote(id: id, isHelpful: isHelpful))
            let localVote = isHelpful ? "helpful" : "not_helpful"
            faqs = faqs.map { faq in
                guard faq.id == id else { return faq }
                return SupportFAQ(
                    id: faq.id, question: faq.question, answer: faq.answer,
                    category: faq.category, helpfulCount: resp.helpfulCount,
                    notHelpfulCount: resp.notHelpfulCount, userVote: localVote
                )
            }
        } catch {
            if !(error is CancellationError) {
                print("[SUPPORT] voteFAQ error: \(error)")
            }
        }
    }

    // MARK: - Fetch Ticket Detail

    func fetchTicketDetail(ticketNumber: String) async {
        do {
            let resp: SupportTicketDetailResponse = try await APIClient.shared.request(
                .ticketDetail(ticketNumber: ticketNumber)
            )
            if tickets.contains(where: { $0.ticketNumber == ticketNumber }) {
                tickets = tickets.map { $0.ticketNumber == ticketNumber ? resp.ticket : $0 }
            } else {
                tickets.insert(resp.ticket, at: 0)
            }
        } catch {
            if !(error is CancellationError) {
                print("[SUPPORT] fetchTicketDetail error: \(error)")
            }
        }
    }

    // MARK: - Error Reset

    func clearCreateError() {
        createTicketError = nil
    }

    // MARK: - Clear on Sign-Out

    func clearAll() {
        tickets = []
        selectedMessages = []
        faqs = []
        ticketsError = nil
        createTicketError = nil
        sendMessageError = nil
        closeTicketError = nil
    }
}

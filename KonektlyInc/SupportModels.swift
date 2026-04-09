//
//  SupportModels.swift
//  KonektlyInc
//

import Foundation
import SwiftUI

// MARK: - Ticket Status

nonisolated enum TicketStatus: String, Codable, CaseIterable, Sendable {
    case open         = "open"
    case inProgress   = "in_progress"
    case waitingOnUser = "waiting_on_user"
    case resolved     = "resolved"
    case closed       = "closed"

    var displayName: String {
        switch self {
        case .open:          return "Open"
        case .inProgress:    return "In Progress"
        case .waitingOnUser: return "Your Reply Needed"
        case .resolved:      return "Resolved"
        case .closed:        return "Closed"
        }
    }

    @MainActor var color: Color {
        switch self {
        case .open:          return Theme.Colors.accent
        case .inProgress:    return Theme.Colors.success
        case .waitingOnUser: return .orange
        case .resolved:      return Theme.Colors.success
        case .closed:        return Theme.Colors.secondaryText
        }
    }

    var isActive: Bool {
        self != .resolved && self != .closed
    }
}

// MARK: - Ticket Category

nonisolated enum TicketCategory: String, Codable, CaseIterable, Sendable {
    case account      = "account"
    case payment      = "payment"
    case job          = "job"
    case subscription = "subscription"
    case verification = "verification"
    case bug          = "bug"
    case other        = "other"

    var displayName: String {
        switch self {
        case .account:      return "Account"
        case .payment:      return "Payment & Billing"
        case .job:          return "Jobs"
        case .subscription: return "Subscription"
        case .verification: return "Verification"
        case .bug:          return "Bug Report"
        case .other:        return "Other"
        }
    }

    var icon: String {
        switch self {
        case .account:      return "person.fill"
        case .payment:      return "creditcard.fill"
        case .job:          return "briefcase.fill"
        case .subscription: return "star.fill"
        case .verification: return "checkmark.shield.fill"
        case .bug:          return "wrench.and.screwdriver.fill"
        case .other:        return "questionmark.circle.fill"
        }
    }
}

// MARK: - Support Ticket

nonisolated struct SupportTicket: Identifiable, Codable, Sendable {
    let id: Int
    let ticketNumber: String
    let subject: String
    let description: String
    let status: String
    let category: String
    let priority: String
    let messageCount: Int
    let assignedToId: Int?
    let assignedToName: String?
    let createdAt: Date
    let updatedAt: Date

    var statusEnum: TicketStatus     { TicketStatus(rawValue: status)     ?? .open    }
    var categoryEnum: TicketCategory { TicketCategory(rawValue: category) ?? .other }
    var isAssigned: Bool             { assignedToId != nil }

    enum CodingKeys: String, CodingKey {
        case id, subject, description, status, category, priority
        case ticketNumber  = "ticket_number"
        case messageCount  = "message_count"
        case assignedToId  = "assigned_to_id"
        case assignedToName = "assigned_to_name"
        case createdAt     = "created_at"
        case updatedAt     = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try  c.decode(Int.self,    forKey: .id)
        ticketNumber    = try  c.decode(String.self, forKey: .ticketNumber)
        subject         = try  c.decode(String.self, forKey: .subject)
        // List endpoint omits description/assignment; default gracefully.
        description     = (try? c.decode(String.self, forKey: .description))     ?? ""
        status          = try  c.decode(String.self, forKey: .status)
        category        = try  c.decode(String.self, forKey: .category)
        priority        = try  c.decode(String.self, forKey: .priority)
        messageCount    = (try? c.decode(Int.self,   forKey: .messageCount))      ?? 0
        assignedToId    = try? c.decode(Int.self,    forKey: .assignedToId)
        assignedToName  = try? c.decode(String.self, forKey: .assignedToName)
        createdAt       = try  c.decode(Date.self,   forKey: .createdAt)
        updatedAt       = try  c.decode(Date.self,   forKey: .updatedAt)
    }

    init(id: Int, ticketNumber: String, subject: String, description: String,
         status: String, category: String, priority: String, messageCount: Int,
         assignedToId: Int? = nil, assignedToName: String? = nil,
         createdAt: Date, updatedAt: Date) {
        self.id              = id
        self.ticketNumber    = ticketNumber
        self.subject         = subject
        self.description     = description
        self.status          = status
        self.category        = category
        self.priority        = priority
        self.messageCount    = messageCount
        self.assignedToId    = assignedToId
        self.assignedToName  = assignedToName
        self.createdAt       = createdAt
        self.updatedAt       = updatedAt
    }

    func withStatus(_ newStatus: TicketStatus) -> SupportTicket {
        SupportTicket(
            id: id, ticketNumber: ticketNumber, subject: subject,
            description: description, status: newStatus.rawValue,
            category: category, priority: priority,
            messageCount: messageCount,
            assignedToId: assignedToId, assignedToName: assignedToName,
            createdAt: createdAt, updatedAt: Date()
        )
    }
}

// MARK: - Ticket Message

nonisolated struct TicketMessage: Identifiable, Codable, Sendable {
    let id: Int
    let body: String
    let senderId: Int?
    let senderName: String?
    let isInternal: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, body
        case senderId   = "sender_id"
        case senderName = "sender_name"
        case isInternal = "is_internal"
        case createdAt  = "created_at"
    }
}

// MARK: - FAQ

nonisolated struct SupportFAQ: Identifiable, Codable, Sendable {
    let id: Int
    let question: String
    let answer: String
    let category: String
    let helpfulCount: Int
    let notHelpfulCount: Int
    let userVote: String?   // "helpful" | "not_helpful" | nil

    enum CodingKeys: String, CodingKey {
        case id, question, answer, category
        case helpfulCount    = "helpful_count"
        case notHelpfulCount = "not_helpful_count"
        case userVote        = "user_vote"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try  c.decode(Int.self,    forKey: .id)
        question        = try  c.decode(String.self, forKey: .question)
        answer          = try  c.decode(String.self, forKey: .answer)
        category        = try  c.decode(String.self, forKey: .category)
        helpfulCount    = (try? c.decode(Int.self,   forKey: .helpfulCount))    ?? 0
        notHelpfulCount = (try? c.decode(Int.self,   forKey: .notHelpfulCount)) ?? 0
        userVote        = try? c.decode(String.self, forKey: .userVote)
    }

    init(id: Int, question: String, answer: String, category: String,
         helpfulCount: Int, notHelpfulCount: Int, userVote: String?) {
        self.id              = id
        self.question        = question
        self.answer          = answer
        self.category        = category
        self.helpfulCount    = helpfulCount
        self.notHelpfulCount = notHelpfulCount
        self.userVote        = userVote
    }
}

// MARK: - Request Types

nonisolated struct CreateTicketRequest: Encodable, Sendable {
    let subject: String
    let description: String
    let category: String
    let priority: String
}

nonisolated struct SendTicketMessageRequest: Encodable, Sendable {
    let body: String
}

nonisolated struct FAQVoteRequest: Encodable, Sendable {
    let isHelpful: Bool

    enum CodingKeys: String, CodingKey {
        case isHelpful = "is_helpful"
    }
}

// MARK: - Response Types

nonisolated struct SupportTicketListResponse: Decodable, Sendable {
    let tickets: [SupportTicket]
}

nonisolated struct SupportTicketDetailResponse: Decodable, Sendable {
    let ticket: SupportTicket
}

nonisolated struct TicketMessageListResponse: Decodable, Sendable {
    let messages: [TicketMessage]
}

nonisolated struct SingleTicketMessageResponse: Decodable, Sendable {
    let message: TicketMessage
}

nonisolated struct FAQListResponse: Decodable, Sendable {
    let faqs: [SupportFAQ]
}

nonisolated struct FAQVoteResponse: Decodable, Sendable {
    let helpfulCount: Int
    let notHelpfulCount: Int

    enum CodingKeys: String, CodingKey {
        case helpfulCount    = "helpful_count"
        case notHelpfulCount = "not_helpful_count"
    }
}

// MARK: - Store Error

enum SupportStoreError: LocalizedError, Equatable {
    case ticketLimitReached
    case ticketNotFound
    case ticketClosed
    case network
    case unknown(String)

    static func from(_ appError: AppError) -> SupportStoreError {
        if case .network = appError { return .network }
        guard case .apiError(let code, let msg) = appError else {
            return .unknown(appError.errorDescription ?? "")
        }
        switch code {
        case .ticketLimitReached:        return .ticketLimitReached
        case .ticketNotFound, .notFound: return .ticketNotFound
        case .ticketAlreadyClosed:       return .ticketClosed
        default: return .unknown(msg.isEmpty ? code.userFacingMessage : msg)
        }
    }

    var errorDescription: String? {
        switch self {
        case .ticketLimitReached:
            return "You have too many open tickets. Please close an existing ticket before creating a new one."
        case .ticketNotFound:
            return "This support ticket could not be found."
        case .ticketClosed:
            return "This ticket is already closed."
        case .network:
            return "Network error. Please check your connection."
        case .unknown(let msg):
            return msg.isEmpty ? "Something went wrong. Please try again." : msg
        }
    }

    static func == (lhs: SupportStoreError, rhs: SupportStoreError) -> Bool {
        switch (lhs, rhs) {
        case (.ticketLimitReached, .ticketLimitReached),
             (.ticketNotFound,     .ticketNotFound),
             (.ticketClosed,       .ticketClosed),
             (.network,            .network):           return true
        case (.unknown(let a), .unknown(let b)):        return a == b
        default:                                        return false
        }
    }
}

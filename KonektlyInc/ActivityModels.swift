//
//  ActivityModels.swift
//  KonektlyInc
//

import Foundation

// MARK: - Activity Feed

nonisolated struct ActivityEvent: Sendable, Identifiable {
    let id: UUID
    let type: String
    let timestamp: Date
    let title: String
    let subtitle: String
}

extension ActivityEvent: Decodable {
    enum CodingKeys: String, CodingKey { case type, timestamp, title, subtitle }

    init(from decoder: Decoder) throws {
        id = UUID()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type      = try c.decode(String.self, forKey: .type)
        timestamp = try c.decode(Date.self,   forKey: .timestamp)
        title     = try c.decode(String.self, forKey: .title)
        subtitle  = try c.decode(String.self, forKey: .subtitle)
    }
}

nonisolated struct ActivityFeedResponse: Decodable, Sendable {
    let events:   [ActivityEvent]
    let total:    Int
    let page:     Int
    let pageSize: Int
    let hasNext:  Bool

    enum CodingKeys: String, CodingKey {
        case events, total, page
        case pageSize = "page_size"
        case hasNext  = "has_next"
    }
}

// MARK: - Stats

nonisolated struct ActivityWorkerStats: Decodable, Sendable {
    let jobsCompleted:    Int
    let jobsScheduled:    Int
    let totalEarnedCents: Int
    let avgRating:        Double
    let reviewCount:      Int
    let applicationsSent: Int
    let acceptanceRate:   Double

    enum CodingKeys: String, CodingKey {
        case jobsCompleted    = "jobs_completed"
        case jobsScheduled    = "jobs_scheduled"
        case totalEarnedCents = "total_earned_cents"
        case avgRating        = "avg_rating"
        case reviewCount      = "review_count"
        case applicationsSent = "applications_sent"
        case acceptanceRate   = "acceptance_rate"
    }
}

nonisolated struct ActivityBusinessStats: Decodable, Sendable {
    let jobsPosted:     Int
    let jobsCompleted:  Int
    let jobsActive:     Int
    let totalSpentCents: Int
    let avgRating:      Double
    let reviewCount:    Int
    let workersHired:   Int

    enum CodingKeys: String, CodingKey {
        case jobsPosted      = "jobs_posted"
        case jobsCompleted   = "jobs_completed"
        case jobsActive      = "jobs_active"
        case totalSpentCents = "total_spent_cents"
        case avgRating       = "avg_rating"
        case reviewCount     = "review_count"
        case workersHired    = "workers_hired"
    }
}

nonisolated struct ActivityStats: Decodable, Sendable {
    let worker:   ActivityWorkerStats?
    let business: ActivityBusinessStats?
}

// MARK: - Job History

nonisolated struct ActivityJob: Sendable, Identifiable {
    let id:             String   // generated from role + ids
    let jobId:          Int
    let shiftId:        Int?
    let role:           String   // "business" | "worker"
    let title:          String
    let status:         String
    let payRate:        String
    let addressDisplay: String?
    let scheduledStart: Date?
    let scheduledEnd:   Date?
    let startTime:      Date?
    let endTime:        Date?
    let createdAt:      Date
}

extension ActivityJob: Decodable {
    enum CodingKeys: String, CodingKey {
        case jobId          = "job_id"
        case shiftId        = "shift_id"
        case role, title, status
        case payRate        = "pay_rate"
        case addressDisplay = "address_display"
        case scheduledStart = "scheduled_start"
        case scheduledEnd   = "scheduled_end"
        case startTime      = "start_time"
        case endTime        = "end_time"
        case createdAt      = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        jobId          = try  c.decode(Int.self,    forKey: .jobId)
        shiftId        = try? c.decode(Int.self,    forKey: .shiftId)
        role           = try  c.decode(String.self, forKey: .role)
        title          = try  c.decode(String.self, forKey: .title)
        status         = try  c.decode(String.self, forKey: .status)
        payRate        = try  c.decode(String.self, forKey: .payRate)
        addressDisplay = try? c.decode(String.self, forKey: .addressDisplay)
        scheduledStart = try? c.decode(Date.self,   forKey: .scheduledStart)
        scheduledEnd   = try? c.decode(Date.self,   forKey: .scheduledEnd)
        startTime      = try? c.decode(Date.self,   forKey: .startTime)
        endTime        = try? c.decode(Date.self,   forKey: .endTime)
        createdAt      = try  c.decode(Date.self,   forKey: .createdAt)
        id             = "\(role)-\(shiftId.map { "\($0)" } ?? "\(jobId)")"
    }

    var displayDate: Date? { startTime ?? scheduledStart ?? createdAt }
}

nonisolated struct ActivityJobHistoryResponse: Decodable, Sendable {
    let jobs:     [ActivityJob]
    let total:    Int
    let page:     Int
    let pageSize: Int
    let hasNext:  Bool

    enum CodingKeys: String, CodingKey {
        case jobs, total, page
        case pageSize = "page_size"
        case hasNext  = "has_next"
    }
}

// MARK: - Payment History

nonisolated struct ActivityPayment: Sendable, Identifiable {
    let id:                UUID
    let jobId:             Int
    let jobTitle:          String
    let role:              String   // "business" | "worker"
    let status:            String
    let grossAmountCents:  Int
    let taxAmountCents:    Int?
    let contractorNetCents: Int?    // worker only
    let authorizedAt:      Date?
    let capturedAt:        Date?
    let transferredAt:     Date?
    let paidOutAt:         Date?
    let refundedAt:        Date?
    let failedAt:          Date?

    var displayAmountCents: Int {
        if role == "worker" { return contractorNetCents ?? grossAmountCents }
        return grossAmountCents
    }

    var displayDate: Date? { paidOutAt ?? transferredAt ?? capturedAt ?? authorizedAt }
}

extension ActivityPayment: Decodable {
    enum CodingKeys: String, CodingKey {
        case jobId             = "job_id"
        case jobTitle          = "job_title"
        case role, status
        case grossAmountCents  = "gross_amount_cents"
        case taxAmountCents    = "tax_amount_cents"
        case contractorNetCents = "contractor_net_cents"
        case authorizedAt      = "authorized_at"
        case capturedAt        = "captured_at"
        case transferredAt     = "transferred_at"
        case paidOutAt         = "paid_out_at"
        case refundedAt        = "refunded_at"
        case failedAt          = "failed_at"
    }

    init(from decoder: Decoder) throws {
        id = UUID()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        jobId              = try  c.decode(Int.self,    forKey: .jobId)
        jobTitle           = try  c.decode(String.self, forKey: .jobTitle)
        role               = try  c.decode(String.self, forKey: .role)
        status             = try  c.decode(String.self, forKey: .status)
        grossAmountCents   = try  c.decode(Int.self,    forKey: .grossAmountCents)
        taxAmountCents     = try? c.decode(Int.self,    forKey: .taxAmountCents)
        contractorNetCents = try? c.decode(Int.self,    forKey: .contractorNetCents)
        authorizedAt       = try? c.decode(Date.self,   forKey: .authorizedAt)
        capturedAt         = try? c.decode(Date.self,   forKey: .capturedAt)
        transferredAt      = try? c.decode(Date.self,   forKey: .transferredAt)
        paidOutAt          = try? c.decode(Date.self,   forKey: .paidOutAt)
        refundedAt         = try? c.decode(Date.self,   forKey: .refundedAt)
        failedAt           = try? c.decode(Date.self,   forKey: .failedAt)
    }
}

nonisolated struct ActivityPaymentHistoryResponse: Decodable, Sendable {
    let payments: [ActivityPayment]
    let total:    Int
    let page:     Int
    let pageSize: Int
    let hasNext:  Bool

    enum CodingKeys: String, CodingKey {
        case payments, total, page
        case pageSize = "page_size"
        case hasNext  = "has_next"
    }
}

// MARK: - Review History

nonisolated struct ActivityReview: Decodable, Sendable, Identifiable {
    let reviewId:     Int
    let jobId:        Int
    let jobTitle:     String
    let direction:    String   // "given" | "received"
    let rating:       Int
    let comment:      String?
    let reviewerType: String
    let reviewerId:   Int?
    let reviewerName: String?
    let revieweeId:   Int?
    let revieweeName: String?
    let createdAt:    Date

    var id: Int { reviewId }

    var otherPersonName: String? {
        direction == "given" ? revieweeName : reviewerName
    }

    enum CodingKeys: String, CodingKey {
        case reviewId    = "review_id"
        case jobId       = "job_id"
        case jobTitle    = "job_title"
        case direction, rating, comment
        case reviewerType = "reviewer_type"
        case reviewerId   = "reviewer_id"
        case reviewerName = "reviewer_name"
        case revieweeId   = "reviewee_id"
        case revieweeName = "reviewee_name"
        case createdAt    = "created_at"
    }
}

nonisolated struct ActivityReviewHistoryResponse: Decodable, Sendable {
    let reviews:  [ActivityReview]
    let total:    Int
    let page:     Int
    let pageSize: Int
    let hasNext:  Bool

    enum CodingKeys: String, CodingKey {
        case reviews, total, page
        case pageSize = "page_size"
        case hasNext  = "has_next"
    }
}

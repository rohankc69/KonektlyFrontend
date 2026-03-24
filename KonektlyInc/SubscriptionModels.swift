//
//  SubscriptionModels.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import Foundation

// MARK: - Backend subscription model

nonisolated struct SubscriptionStatus: Codable, Sendable {
    let plan: String              // "free" | "konektly_plus"
    let planDisplay: String
    let status: String            // "active" | "cancelled" | "expired"
    let statusDisplay: String
    let isKonektlyPlus: Bool      // USE THIS for all feature gates
    let expiresAt: Date?
    let startedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case plan, status
        case planDisplay = "plan_display"
        case statusDisplay = "status_display"
        case isKonektlyPlus = "is_konektly_plus"
        case expiresAt = "expires_at"
        case startedAt = "started_at"
    }
}

// MARK: - Validate endpoint request/response

nonisolated struct AppleValidateRequest: Encodable, Sendable {
    let jwsTransaction: String
    
    enum CodingKeys: String, CodingKey {
        case jwsTransaction = "jws_transaction"
    }
}

// Response is the same SubscriptionStatus shape above

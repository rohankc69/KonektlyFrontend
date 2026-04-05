//
//  NotificationRoutingStore.swift
//  KonektlyInc
//
//  Deep-link targets from FCM data payloads (marketing / campaign pushes).
//

import Foundation
import Combine

@MainActor
final class NotificationRoutingStore: ObservableObject {
    static let shared = NotificationRoutingStore()

    /// Set when user taps a push whose `data.type` is marketing, promotional, re_engagement, transactional, or test_notification.
    @Published var pendingTemplateId: String?
    @Published var pendingCampaignId: String?

    func consumePending() -> (templateId: String?, campaignId: String?) {
        let t = pendingTemplateId
        let c = pendingCampaignId
        pendingTemplateId = nil
        pendingCampaignId = nil
        return (t, c)
    }
}

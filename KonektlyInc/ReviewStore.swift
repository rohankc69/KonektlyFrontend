//
//  ReviewStore.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-25.
//

import Foundation
import Combine

@MainActor
final class ReviewStore: ObservableObject {
    static let shared = ReviewStore()
    private init() {}

    @Published var pendingReviews: [PendingReviewJob] = []
    @Published var pendingCount: Int = 0

    func loadPendingReviews() async {
        do {
            let resp: PendingReviewsResponse = try await APIClient.shared.request(.pendingReviews)
            pendingReviews = resp.jobs
            pendingCount = resp.jobs.count
        } catch {
            print("[REVIEWS] loadPending error: \(error)")
        }
    }

    func submitReview(jobId: Int, rating: Int, comment: String?, idempotencyKey: String) async throws -> ReviewResponse {
        let req = ReviewRequest(jobId: jobId, rating: rating, comment: comment)
        let resp: SubmitReviewResponse = try await APIClient.shared.request(.submitReview(req, idempotencyKey: idempotencyKey))
        // Remove from pending
        pendingReviews.removeAll { $0.id == jobId }
        pendingCount = pendingReviews.count
        return resp.review
    }

    func fetchUserReviews(userId: Int) async throws -> [ReviewResponse] {
        let resp: ReviewsListResponse = try await APIClient.shared.request(.userReviews(userId: userId))
        return resp.reviews
    }

    func clearAll() {
        pendingReviews = []
        pendingCount = 0
    }
}

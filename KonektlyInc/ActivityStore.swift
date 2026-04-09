//
//  ActivityStore.swift
//  KonektlyInc
//

import Foundation
import Combine

@MainActor
final class ActivityStore: ObservableObject {
    static let shared = ActivityStore()
    private init() {}

    // MARK: - Stats

    @Published var stats: ActivityStats?
    @Published var isStatsLoading = false

    // MARK: - Feed

    @Published var feedEvents: [ActivityEvent] = []
    @Published var isFeedLoading = false
    @Published var feedHasNext = false
    private var feedPage = 1

    // MARK: - Jobs

    @Published var jobs: [ActivityJob] = []
    @Published var isJobsLoading = false
    @Published var jobsHasNext = false
    private var jobsPage = 1
    private(set) var jobsRole = ""   // "", "business", "worker"

    // MARK: - Payments

    @Published var payments: [ActivityPayment] = []
    @Published var isPaymentsLoading = false
    @Published var paymentsHasNext = false
    private var paymentsPage = 1

    // MARK: - Reviews

    @Published var reviews: [ActivityReview] = []
    @Published var isReviewsLoading = false
    @Published var reviewsHasNext = false
    private var reviewsPage = 1
    private(set) var reviewsDirection = ""   // "", "given", "received"

    // MARK: - Load Stats

    func loadStats() async {
        guard !isStatsLoading else { return }
        isStatsLoading = true
        defer { isStatsLoading = false }
        do {
            let result: ActivityStats = try await APIClient.shared.request(.activityStats)
            stats = result
        } catch {
            if !(error is CancellationError) {
                print("[ACTIVITY] loadStats failed: \(error)")
            }
        }
    }

    // MARK: - Load Feed

    func loadFeed(reset: Bool = false) async {
        if reset {
            feedPage = 1
            feedEvents = []
        }
        guard !isFeedLoading else { return }
        isFeedLoading = true
        defer { isFeedLoading = false }
        do {
            let resp: ActivityFeedResponse = try await APIClient.shared.request(
                .activityFeed(page: feedPage, pageSize: 20)
            )
            feedEvents += resp.events
            feedHasNext = resp.hasNext
            if resp.hasNext { feedPage += 1 }
        } catch {
            if !(error is CancellationError) {
                print("[ACTIVITY] loadFeed failed: \(error)")
            }
        }
    }

    // MARK: - Load Jobs

    func loadJobs(role: String = "", reset: Bool = false) async {
        if reset || role != jobsRole {
            jobsPage = 1
            jobs = []
            jobsRole = role
        }
        guard !isJobsLoading else { return }
        isJobsLoading = true
        defer { isJobsLoading = false }
        do {
            let resp: ActivityJobHistoryResponse = try await APIClient.shared.request(
                .activityJobs(role: jobsRole, page: jobsPage, pageSize: 20)
            )
            jobs += resp.jobs
            jobsHasNext = resp.hasNext
            if resp.hasNext { jobsPage += 1 }
        } catch {
            if !(error is CancellationError) {
                print("[ACTIVITY] loadJobs failed: \(error)")
            }
        }
    }

    // MARK: - Load Payments

    func loadPayments(reset: Bool = false) async {
        if reset {
            paymentsPage = 1
            payments = []
        }
        guard !isPaymentsLoading else { return }
        isPaymentsLoading = true
        defer { isPaymentsLoading = false }
        do {
            let resp: ActivityPaymentHistoryResponse = try await APIClient.shared.request(
                .activityPayments(page: paymentsPage, pageSize: 20)
            )
            payments += resp.payments
            paymentsHasNext = resp.hasNext
            if resp.hasNext { paymentsPage += 1 }
        } catch {
            if !(error is CancellationError) {
                print("[ACTIVITY] loadPayments failed: \(error)")
            }
        }
    }

    // MARK: - Load Reviews

    func loadReviews(direction: String = "", reset: Bool = false) async {
        if reset || direction != reviewsDirection {
            reviewsPage = 1
            reviews = []
            reviewsDirection = direction
        }
        guard !isReviewsLoading else { return }
        isReviewsLoading = true
        defer { isReviewsLoading = false }
        do {
            let resp: ActivityReviewHistoryResponse = try await APIClient.shared.request(
                .activityReviews(direction: reviewsDirection, page: reviewsPage, pageSize: 20)
            )
            reviews += resp.reviews
            reviewsHasNext = resp.hasNext
            if resp.hasNext { reviewsPage += 1 }
        } catch {
            if !(error is CancellationError) {
                print("[ACTIVITY] loadReviews failed: \(error)")
            }
        }
    }

    // MARK: - Clear on Sign-Out

    func clearAll() {
        stats = nil
        feedEvents = []
        feedPage = 1
        feedHasNext = false
        jobs = []
        jobsPage = 1
        jobsHasNext = false
        jobsRole = ""
        payments = []
        paymentsPage = 1
        paymentsHasNext = false
        reviews = []
        reviewsPage = 1
        reviewsHasNext = false
        reviewsDirection = ""
    }
}

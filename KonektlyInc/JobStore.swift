//
//  JobStore.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-07.
//

import Foundation
import Combine

// MARK: - Job Store State

enum JobStoreError: LocalizedError, Equatable {
    case alreadyApplied
    case jobNotOpen
    case jobNotFilled
    case jobAlreadyCompleted
    case applicationAlreadyProcessed
    case permissionDenied
    case locationRequired
    case geocodeFailed
    case notFound
    case general(String)

    var errorDescription: String? {
        switch self {
        case .alreadyApplied:                return "You have already applied for this job."
        case .jobNotOpen:                    return "This job is no longer accepting applications."
        case .jobNotFilled:                  return "Hire a worker before marking complete."
        case .jobAlreadyCompleted:           return "This job is already completed."
        case .applicationAlreadyProcessed:  return "This application has already been processed."
        case .permissionDenied:             return "You don't have permission to perform this action."
        case .locationRequired:             return "Allow location access or enter your postal code."
        case .geocodeFailed:                return "Address not found — try a different address or use GPS."
        case .notFound:                     return "The requested item could not be found."
        case .general(let msg):             return msg
        }
    }

    static func from(_ appError: AppError) -> JobStoreError {
        if case .decoding = appError {
            return .general("We couldn't read the latest jobs data. Please try again.")
        }
        if case .apiError(let code, let message) = appError {
            switch code {
            case .alreadyApplied:                return .alreadyApplied
            case .jobNotOpen:                    return .jobNotOpen
            case .applicationAlreadyProcessed:  return .applicationAlreadyProcessed
            case .permissionDenied:              return .permissionDenied
            case .locationRequired:              return .locationRequired
            case .geocodeFailed:                 return .geocodeFailed
            case .notFound:                      return .notFound
            default:
                // Map 409 JOB_NOT_FILLED / JOB_ALREADY_COMPLETED by message content
                if message.lowercased().contains("not filled") { return .jobNotFilled }
                if message.lowercased().contains("already completed") { return .jobAlreadyCompleted }
                return .general(message)
            }
        }
        return .general(appError.errorDescription ?? "An unexpected error occurred.")
    }
}

// MARK: - Job Store

/// Centralised state for Jobs, Applications and the Post-Job flow.
/// All mutations happen on the MainActor so @Published properties update SwiftUI safely.
@MainActor
final class JobStore: ObservableObject {

    static let shared = JobStore()
    private init() {}

    // MARK: - Published State

    /// Nearby open jobs (worker feed)
    @Published private(set) var nearbyJobs: [APIJob] = []
    @Published private(set) var isLoadingNearbyJobs = false
    @Published private(set) var nearbyJobsError: JobStoreError? = nil

    /// Business: my posted jobs (populated from post + fetchPostedJobs)
    @Published private(set) var postedJobs: [APIJob] = []
    @Published private(set) var isLoadingPostedJobs = false
    @Published private(set) var postedJobsError: JobStoreError? = nil
    @Published private(set) var isPostingJob = false
    @Published private(set) var postJobError: JobStoreError? = nil

    /// Business: applicants for a selected job
    @Published private(set) var applications: [JobApplication] = []
    @Published private(set) var isLoadingApplications = false
    @Published private(set) var applicationsError: JobStoreError? = nil

    /// Business: nearby workers for a selected job
    @Published private(set) var nearbyWorkers: [NearbyWorker] = []
    @Published private(set) var isLoadingNearbyWorkers = false
    @Published private(set) var nearbyWorkersError: JobStoreError? = nil

    /// Worker: apply-for-job state
    @Published private(set) var isApplying = false
    @Published private(set) var applyError: JobStoreError? = nil
    /// The most recently submitted application (so the UI can show pending state)
    @Published private(set) var lastSubmittedApplication: JobApplication? = nil

    /// Worker: my applications (GET /api/v1/my/applications/)
    /// activeApplications  — pending + accepted (drives "Applied" tab)
    /// completedApplications — accepted where job.status == completed (drives "Completed" tab)
    @Published private(set) var activeApplications: [MyApplicationItem] = []
    @Published private(set) var completedApplications: [MyApplicationItem] = []
    @Published private(set) var isLoadingMyApplications = false
    @Published private(set) var myApplicationsError: JobStoreError? = nil

    /// Worker: set of jobIds applied this session (immediate, before /my/applications/ is fetched)
    @Published private(set) var appliedJobIds: Set<Int> = []

    /// Deep-link: set by push notification tap to navigate to a specific job
    @Published var pendingDeepLinkJobId: Int?

    /// Business: hire state
    @Published private(set) var isHiring = false
    @Published private(set) var hireError: JobStoreError? = nil

    /// Business: complete job state
    @Published private(set) var isCompleting = false
    @Published private(set) var completeError: JobStoreError? = nil
    @Published var completionReview: JobCompletionReview? = nil
    @Published var completionJobId: Int? = nil
    @Published var completionJobTitle: String? = nil

    /// Refresh/task cancellations are expected during pull-to-refresh and tab/view transitions.
    /// Ignore them so we don't show a false "No internet" banner.
    private func isCancellation(_ error: any Error) -> Bool {
        if error is CancellationError { return true }
        if case .network(let underlying) = (error as? AppError), let urlError = underlying as? URLError {
            return urlError.code == .cancelled
        }
        return false
    }

    // MARK: - Worker: Fetch Nearby Jobs

    /// Fetch open jobs near the given GPS coordinates.
    /// - Parameters:
    ///   - lat: Device latitude (preferred).
    ///   - lng: Device longitude (preferred).
    ///   - postalCode: Fallback when GPS is unavailable.
    ///   - radius: Search radius in km (default 10, max 250).
    ///   - forceRefresh: Bypass the isLoading guard and clear stale errors (use from .refreshable).
    func fetchNearbyJobs(lat: Double? = nil, lng: Double? = nil,
                         postalCode: String? = nil, radius: Int? = nil,
                         filter: String? = nil,
                         forceRefresh: Bool = false) async {
        guard !isLoadingNearbyJobs || forceRefresh else { return }
        isLoadingNearbyJobs = true
        nearbyJobsError = nil
        defer { isLoadingNearbyJobs = false }

        do {
            let endpoint = Endpoint.nearbyJobs(lat: lat, lng: lng,
                                               postalCode: postalCode, radius: radius,
                                               filter: filter)
            let response: NearbyJobsResponse = try await APIClient.shared.request(endpoint)
            nearbyJobs = response.jobs
            print("[JOBS] fetchNearbyJobs: \(response.count) jobs (filter=\(filter ?? "all"))")
        } catch {
            if isCancellation(error) {
                print("[JOBS] fetchNearbyJobs cancelled")
                return
            }
            let storeError = JobStoreError.from(error as? AppError ?? .unknown)
            nearbyJobsError = storeError
            print("[JOBS] fetchNearbyJobs error: \(storeError.errorDescription ?? "")")
        }
    }

    // MARK: - Business: Fetch Posted Jobs

    /// Load all jobs posted by this business (GET /api/v1/jobs/mine/).
    /// Merges server results with any jobs posted this session so nothing is lost.
    /// - Parameter forceRefresh: Bypass isLoading guard — use from .refreshable.
    func fetchPostedJobs(forceRefresh: Bool = false) async {
        guard !isLoadingPostedJobs || forceRefresh else { return }
        isLoadingPostedJobs = true
        postedJobsError = nil           // always clear stale error on refresh
        defer { isLoadingPostedJobs = false }

        do {
            let response: NearbyJobsResponse = try await APIClient.shared.request(.myPostedJobs())
            // Merge: server is source of truth, but keep any session-posted jobs
            // that the server might not return yet (race condition on very fast posts)
            let serverIds = Set(response.jobs.map { $0.id })
            let sessionOnly = postedJobs.filter { !serverIds.contains($0.id) }
            postedJobs = (sessionOnly + response.jobs)
                .sorted { $0.scheduledStart > $1.scheduledStart }
            print("[JOBS] fetchPostedJobs: \(response.count) jobs loaded")
        } catch {
            if isCancellation(error) {
                print("[JOBS] fetchPostedJobs cancelled")
                return
            }
            let storeError = JobStoreError.from(error as? AppError ?? .unknown)
            postedJobsError = storeError
            print("[JOBS] fetchPostedJobs error: \(storeError.errorDescription ?? "")")
        }
    }

    // MARK: - Business: Post a Job

    /// Post a new open job. Appends to postedJobs on success.
    /// - Parameters:
    ///   - title: Job title.
    ///   - description: Optional free-form description.
    ///   - payRate: Decimal string, e.g. "18.50".
    ///   - scheduledStart: Shift start time (UTC).
    ///   - scheduledEnd: Optional shift end time (must be after start).
    ///   - lat: GPS latitude (preferred over address).
    ///   - lng: GPS longitude.
    ///   - address: Fallback text address (geocoded server-side).
    /// - Returns: The created `APIJob` on success, `nil` on failure (check `postJobError`).
    @discardableResult
    func postJob(title: String,
                 description: String?,
                 payRate: String,
                 scheduledStart: Date,
                 scheduledEnd: Date?,
                 lat: Double?,
                 lng: Double?,
                 address: String?) async -> APIJob? {
        guard !isPostingJob else { return nil }
        isPostingJob = true
        postJobError = nil
        defer { isPostingJob = false }

        let req = PostJobRequest(
            title: title,
            description: description,
            payRate: payRate,
            scheduledStart: scheduledStart,
            scheduledEnd: scheduledEnd,
            lat: lat,
            lng: lng,
            address: address
        )

        do {
            let response: PostJobResponse = try await APIClient.shared.request(.postJob(req))
            postedJobs.insert(response.job, at: 0)
            print("[JOBS] postJob: created job id=\(response.job.id)")
            return response.job
        } catch {
            let storeError = JobStoreError.from(error as? AppError ?? .unknown)
            postJobError = storeError
            print("[JOBS] postJob error: \(storeError.errorDescription ?? "")")
            return nil
        }
    }

    // MARK: - Business: List Applicants

    /// Load all applications for the given job (business only).
    /// Writes to the shared `applications` array — use `fetchApplicationsForCard` from list cards.
    func fetchApplications(jobId: Int) async {
        guard !isLoadingApplications else { return }
        isLoadingApplications = true
        applicationsError = nil
        defer { isLoadingApplications = false }

        do {
            let response: JobApplicationsResponse = try await APIClient.shared.request(.jobApplications(jobId: jobId))
            applications = response.applications
            print("[JOBS] fetchApplications: \(response.count) applications for jobId=\(jobId)")
        } catch {
            let storeError = JobStoreError.from(error as? AppError ?? .unknown)
            applicationsError = storeError
            print("[JOBS] fetchApplications error: \(storeError.errorDescription ?? "")")
        }
    }

    /// Card-scoped variant — returns the applications directly so each PostedJobListCard
    /// maintains its own isolated list instead of reading the shared global array.
    /// This prevents Card B from briefly showing Card A's applicants during concurrent expands.
    func fetchApplicationsForCard(jobId: Int) async -> [JobApplication] {
        do {
            let response: JobApplicationsResponse = try await APIClient.shared.request(.jobApplications(jobId: jobId))
            print("[JOBS] fetchApplicationsForCard: \(response.count) for jobId=\(jobId)")
            return response.applications
        } catch {
            print("[JOBS] fetchApplicationsForCard error for jobId=\(jobId): \(error)")
            return []
        }
    }

    // MARK: - Business: Workers Near a Job

    /// Fetch workers near the specified job (business/owner only).
    func fetchWorkersNearJob(jobId: Int, radius: Int? = nil) async {
        guard !isLoadingNearbyWorkers else { return }
        isLoadingNearbyWorkers = true
        nearbyWorkersError = nil
        defer { isLoadingNearbyWorkers = false }

        do {
            let response: NearbyWorkersResponse = try await APIClient.shared.request(
                .workersNearJob(jobId: jobId, radius: radius))
            nearbyWorkers = response.workers
            print("[JOBS] fetchWorkersNearJob: \(response.count) workers near jobId=\(jobId)")
        } catch {
            let storeError = JobStoreError.from(error as? AppError ?? .unknown)
            nearbyWorkersError = storeError
            print("[JOBS] fetchWorkersNearJob error: \(storeError.errorDescription ?? "")")
        }
    }

    // MARK: - Worker: Apply for a Job

    /// Apply for the given job. Returns the created application on success.
    /// - Parameters:
    ///   - jobId: The job to apply for.
    ///   - coverNote: Optional message to the business (max 2000 chars).
    /// - Returns: The created `JobApplication` on success, `nil` on failure (check `applyError`).
    @discardableResult
    func applyForJob(jobId: Int, coverNote: String? = nil) async -> JobApplication? {
        guard !isApplying else { return nil }
        isApplying = true
        applyError = nil
        lastSubmittedApplication = nil
        defer { isApplying = false }

        do {
            let response: ApplyForJobResponse = try await APIClient.shared.request(
                .applyForJob(jobId: jobId, coverNote: coverNote))
            lastSubmittedApplication = response.application
            appliedJobIds.insert(jobId)

            // Immediately synthesize a MyApplicationItem so the Applied tab
            // updates without needing a separate network round-trip.
            // We build it from the job we already have in nearbyJobs.
            if let sourceJob = nearbyJobs.first(where: { $0.id == jobId }) {
                let embeddedJob = MyApplicationJob(
                    id: sourceJob.id,
                    title: sourceJob.title,
                    status: sourceJob.status,
                    payRate: sourceJob.payRate,
                    scheduledStart: sourceJob.scheduledStart,
                    addressDisplay: sourceJob.addressDisplay,
                    distanceKm: sourceJob.distanceKm,
                    distanceM: sourceJob.distanceM
                )
                let item = MyApplicationItem(
                    id: response.application.id,
                    status: ApplicationStatus.pending.rawValue,
                    coverNote: coverNote,
                    createdAt: Date(),
                    updatedAt: Date(),
                    job: embeddedJob
                )
                // Insert at top — most recent first
                activeApplications.insert(item, at: 0)
            }

            print("[JOBS] applyForJob: application id=\(response.application.id) status=\(response.application.status)")
            return response.application
        } catch {
            let storeError = JobStoreError.from(error as? AppError ?? .unknown)
            applyError = storeError
            if storeError == .alreadyApplied { appliedJobIds.insert(jobId) }
            print("[JOBS] applyForJob error: \(storeError.errorDescription ?? "")")
            return nil
        }
    }

    // MARK: - Worker: Fetch My Applications

    /// Fetches the worker's applications. Pass lat/lng for distance badges on each card.
    /// - Parameter forceRefresh: Bypass isLoading guard — use from .refreshable.
    func fetchMyApplications(lat: Double? = nil, lng: Double? = nil,
                              forceRefresh: Bool = false) async {
        guard !isLoadingMyApplications || forceRefresh else { return }
        isLoadingMyApplications = true
        myApplicationsError = nil       // always clear stale error on refresh
        defer { isLoadingMyApplications = false }

        do {
            async let pendingResponse: MyApplicationsResponse  = APIClient.shared.request(
                .myApplications(status: "pending",  lat: lat, lng: lng))
            async let acceptedResponse: MyApplicationsResponse = APIClient.shared.request(
                .myApplications(status: "accepted", lat: lat, lng: lng))

            let (pending, accepted) = try await (pendingResponse, acceptedResponse)

            let acceptedActive = accepted.applications.filter {
                $0.job.jobStatusEnum != .completed
            }
            activeApplications = (pending.applications + acceptedActive)
                .sorted { $0.updatedAt > $1.updatedAt }

            completedApplications = accepted.applications
                .filter { $0.job.jobStatusEnum == .completed }
                .sorted { $0.updatedAt > $1.updatedAt }

            print("[JOBS] fetchMyApplications: \(pending.count) pending, \(accepted.count) accepted")
        } catch {
            if isCancellation(error) {
                print("[JOBS] fetchMyApplications cancelled")
                return
            }
            let storeError = JobStoreError.from(error as? AppError ?? .unknown)
            myApplicationsError = storeError
            print("[JOBS] fetchMyApplications error: \(storeError.errorDescription ?? "")")
        }
    }

    // MARK: - Business: Hire a Worker

    /// Hire the given applicant for the job (atomic — also fills job + rejects others).
    /// On success, updates the local `applications` list to reflect new statuses.
    /// - Parameters:
    ///   - jobId: The job to fill.
    ///   - applicationId: The application to accept.
    /// - Returns: The accepted `JobApplication` on success, `nil` on failure (check `hireError`).
    @discardableResult
    func hireWorker(jobId: Int, applicationId: Int) async -> JobApplication? {
        guard !isHiring else { return nil }
        isHiring = true
        hireError = nil
        defer { isHiring = false }

        do {
            let response: HireWorkerResponse = try await APIClient.shared.request(
                .hireWorker(jobId: jobId, applicationId: applicationId))
            let hired = response.application
            print("[JOBS] hireWorker: hired applicationId=\(hired.id) workerId=\(hired.workerId)")

            // Update local applications list
            applications = applications.map { app in
                if app.id == hired.id {
                    return hired  // accepted (as returned by backend)
                }
                // Backend atomically rejected all other pending apps; reflect that locally
                if app.status == ApplicationStatus.pending.rawValue {
                    return app.withStatus(.rejected)
                }
                return app
            }

            // Mark the job as filled in postedJobs
            postedJobs = postedJobs.map { job in
                job.id == jobId ? job.withStatus(.filled) : job
            }

            // Hiring creates a conversation atomically — refresh messages list
            Task {
                await MessageStore.shared.loadConversations()
            }

            return hired
        } catch {
            let storeError = JobStoreError.from(error as? AppError ?? .unknown)
            hireError = storeError
            print("[JOBS] hireWorker error: \(storeError.errorDescription ?? "")")
            return nil
        }
    }

    // MARK: - Business: Mark Job Complete

    /// POST /api/v1/jobs/{jobId}/complete/ — transitions a filled job → completed.
    /// On success, updates job status locally so the UI transitions instantly.
    @discardableResult
    func markJobComplete(jobId: Int) async -> Bool {
        guard !isCompleting else { return false }
        isCompleting = true
        completeError = nil
        defer { isCompleting = false }

        do {
            // Try to parse review data from the completion response
            let resp: JobCompleteResponse = try await APIClient.shared.request(.completeJob(jobId: jobId))
            // Transition job locally: filled → completed
            postedJobs = postedJobs.map { job in
                job.id == jobId ? job.withStatus(.completed) : job
            }
            // Store review info if eligible
            if let review = resp.review, review.eligible {
                completionJobId = jobId
                completionJobTitle = resp.job.title
                completionReview = review
            }
            print("[JOBS] markJobComplete: jobId=\(jobId) → completed, reviewEligible=\(resp.review?.eligible ?? false)")
            return true
        } catch {
            let storeError = JobStoreError.from(error as? AppError ?? .unknown)
            completeError = storeError
            // If already completed, refresh to sync server state
            if storeError == .jobAlreadyCompleted {
                await fetchPostedJobs(forceRefresh: true)
            }
            print("[JOBS] markJobComplete error: \(storeError.errorDescription ?? "")")
            return false
        }
    }

    // MARK: - Helpers

    /// Clear all job-related state (e.g. on sign-out).
    func clearAll() {
        pendingDeepLinkJobId = nil
        appliedJobIds = []
        nearbyJobs = []
        postedJobs = []
        applications = []
        nearbyWorkers = []
        activeApplications = []
        completedApplications = []
        lastSubmittedApplication = nil
        nearbyJobsError = nil
        postedJobsError = nil
        postJobError = nil
        applicationsError = nil
        nearbyWorkersError = nil
        applyError = nil
        hireError = nil
        completeError = nil
        myApplicationsError = nil
    }

    /// Fetch a single job by ID and inject it into nearbyJobs if not already present.
    /// Used for deep-link from push notification.
    func fetchAndInjectJob(jobId: Int) async -> APIJob? {
        // Already in the list?
        if let existing = nearbyJobs.first(where: { $0.id == jobId }) {
            return existing
        }
        do {
            let response: JobDetailResponse = try await APIClient.shared.request(.jobDetail(jobId: jobId))
            let job = response.job
            // Insert at the top so it's visible
            nearbyJobs.insert(job, at: 0)
            return job
        } catch {
            print("[JOBS] fetchAndInjectJob failed: \(error)")
            return nil
        }
    }

    /// Whether the worker has already applied for a given job.
    /// Three sources checked in priority order:
    ///   1. `appliedJobIds` — populated immediately on a successful apply this session
    ///   2. `activeApplications` — fetched from /my/applications/?status=pending|accepted
    ///   3. `completedApplications` — fetched from /my/applications/?status=accepted (completed jobs)
    func hasApplied(jobId: Int) -> Bool {
        appliedJobIds.contains(jobId)
            || activeApplications.contains { $0.job.id == jobId }
            || completedApplications.contains { $0.job.id == jobId }
    }
}

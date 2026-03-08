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
        case .applicationAlreadyProcessed:  return "This application has already been processed."
        case .permissionDenied:             return "You don't have permission to perform this action."
        case .locationRequired:             return "Allow location access or enter your postal code."
        case .geocodeFailed:                return "Address not found — try a different address or use GPS."
        case .notFound:                     return "The requested item could not be found."
        case .general(let msg):             return msg
        }
    }

    // Map APIErrorCode to a typed JobStoreError
    static func from(_ appError: AppError) -> JobStoreError {
        if case .apiError(let code, let message) = appError {
            switch code {
            case .alreadyApplied:                return .alreadyApplied
            case .jobNotOpen:                    return .jobNotOpen
            case .applicationAlreadyProcessed:  return .applicationAlreadyProcessed
            case .permissionDenied:              return .permissionDenied
            case .locationRequired:              return .locationRequired
            case .geocodeFailed:                 return .geocodeFailed
            case .notFound:                      return .notFound
            default:                             return .general(message)
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

    /// Business: my posted jobs (populated from post + future list endpoint)
    @Published private(set) var postedJobs: [APIJob] = []
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

    /// Business: hire state
    @Published private(set) var isHiring = false
    @Published private(set) var hireError: JobStoreError? = nil

    // MARK: - Worker: Fetch Nearby Jobs

    /// Fetch open jobs near the given GPS coordinates.
    /// - Parameters:
    ///   - lat: Device latitude (preferred).
    ///   - lng: Device longitude (preferred).
    ///   - postalCode: Fallback when GPS is unavailable.
    ///   - radius: Search radius in km (default 10, max 250).
    func fetchNearbyJobs(lat: Double? = nil, lng: Double? = nil,
                         postalCode: String? = nil, radius: Int? = nil) async {
        guard !isLoadingNearbyJobs else { return }
        isLoadingNearbyJobs = true
        nearbyJobsError = nil
        defer { isLoadingNearbyJobs = false }

        do {
            let endpoint = Endpoint.nearbyJobs(lat: lat, lng: lng,
                                               postalCode: postalCode, radius: radius)
            let response: NearbyJobsResponse = try await APIClient.shared.request(endpoint)
            nearbyJobs = response.jobs
            print("[JOBS] fetchNearbyJobs: \(response.count) jobs returned")
        } catch {
            let storeError = JobStoreError.from(error as? AppError ?? .unknown)
            nearbyJobsError = storeError
            print("[JOBS] fetchNearbyJobs error: \(storeError.errorDescription ?? "")")
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
            print("[JOBS] applyForJob: application id=\(response.application.id) status=\(response.application.status)")
            return response.application
        } catch {
            let storeError = JobStoreError.from(error as? AppError ?? .unknown)
            applyError = storeError
            print("[JOBS] applyForJob error: \(storeError.errorDescription ?? "")")
            return nil
        }
    }

    // MARK: - Worker: Fetch My Applications

    /// Fetches the worker's applications using the ?status= filter the backend supports.
    /// Makes two requests in parallel:
    ///   1. ?status=pending  → pending apps  (Applied tab)
    ///   2. ?status=accepted → accepted apps (both tabs — Completed filtered client-side by job.status)
    /// The rejected tab is intentionally omitted — rejected apps aren't shown per UX decision.
    func fetchMyApplications() async {
        guard !isLoadingMyApplications else { return }
        isLoadingMyApplications = true
        myApplicationsError = nil
        defer { isLoadingMyApplications = false }

        do {
            // Fetch pending and accepted in parallel
            async let pendingResponse: MyApplicationsResponse  = APIClient.shared.request(.myApplications(status: "pending"))
            async let acceptedResponse: MyApplicationsResponse = APIClient.shared.request(.myApplications(status: "accepted"))

            let (pending, accepted) = try await (pendingResponse, acceptedResponse)

            // Applied tab: pending first (most recent updated_at), then accepted-but-not-completed
            let acceptedActive = accepted.applications.filter {
                $0.job.jobStatusEnum != .completed
            }
            activeApplications = (pending.applications + acceptedActive)
                .sorted { $0.updatedAt > $1.updatedAt }

            // Completed tab: accepted where the job itself is completed
            completedApplications = accepted.applications
                .filter { $0.job.jobStatusEnum == .completed }
                .sorted { $0.updatedAt > $1.updatedAt }

            print("[JOBS] fetchMyApplications: \(pending.count) pending, \(accepted.count) accepted")
        } catch {
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

            return hired
        } catch {
            let storeError = JobStoreError.from(error as? AppError ?? .unknown)
            hireError = storeError
            print("[JOBS] hireWorker error: \(storeError.errorDescription ?? "")")
            return nil
        }
    }

    // MARK: - Helpers

    /// Clear all job-related state (e.g. on sign-out).
    func clearAll() {
        nearbyJobs = []
        postedJobs = []
        applications = []
        nearbyWorkers = []
        activeApplications = []
        completedApplications = []
        lastSubmittedApplication = nil
        nearbyJobsError = nil
        postJobError = nil
        applicationsError = nil
        nearbyWorkersError = nil
        applyError = nil
        hireError = nil
        myApplicationsError = nil
    }

    /// Whether the worker has already applied for a given job
    /// (based on `lastSubmittedApplication` — local only until a My Applications endpoint exists).
    func hasApplied(jobId: Int) -> Bool {
        lastSubmittedApplication?.workerId != nil  // placeholder — extend when /my/applications/ lands
    }
}

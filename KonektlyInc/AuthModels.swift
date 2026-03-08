//
//  AuthModels.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import Foundation

// MARK: - Generic API Response Envelope

nonisolated struct APIResponse<T: Decodable>: Decodable, Sendable where T: Sendable {
    let success: Bool
    let data: T?
    let message: String?
    let error: APIErrorPayload?
}

nonisolated struct APIErrorPayload: Decodable, Sendable {
    let code: String
    let message: String
    let details: AnyCodable?
}

// MARK: - AnyCodable (lightweight, no external deps)

nonisolated struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else if let string = try? container.decode(String.self) { value = string }
        else if let dict = try? container.decode([String: AnyCodable].self) { value = dict }
        else if let array = try? container.decode([AnyCodable].self) { value = array }
        else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let bool as Bool: try container.encode(bool)
        case let string as String: try container.encode(string)
        case let dict as [String: AnyCodable]: try container.encode(dict)
        case let array as [AnyCodable]: try container.encode(array)
        default: try container.encodeNil()
        }
    }
}

// MARK: - API Error Codes

nonisolated enum APIErrorCode: String, Sendable {
    // Auth
    case invalidPhone = "INVALID_PHONE"
    case invalidOTP = "INVALID_OTP"
    case otpExpired = "OTP_EXPIRED"
    case otpInvalid = "OTP_INVALID"
    case otpRateLimit = "OTP_RATE_LIMIT"
    case otpServiceUnavailable = "OTP_SERVICE_UNAVAILABLE"
    case firebaseError = "FIREBASE_ERROR"
    case authenticationError = "AUTHENTICATION_ERROR"
    case tokenExpired = "TOKEN_EXPIRED"
    case unauthorized = "UNAUTHORIZED"
    case emailAlreadyVerified = "EMAIL_ALREADY_VERIFIED"
    case emailTokenInvalid = "EMAIL_TOKEN_INVALID"
    case emailTokenExpired = "EMAIL_TOKEN_EXPIRED"
    // Profile
    case profileAlreadyExists = "PROFILE_ALREADY_EXISTS"
    case profileNotFound = "PROFILE_NOT_FOUND"
    case conflict = "CONFLICT"
    case validationError = "VALIDATION_ERROR"
    // Generic
    case rateLimited = "RATE_LIMITED"
    // Photo
    case invalidFileType = "INVALID_FILE_TYPE"
    case fileTooLarge = "FILE_TOO_LARGE"
    case uploadFailed = "UPLOAD_FAILED"
    case photoNotFound = "PHOTO_NOT_FOUND"
    case phoneNotVerified = "PHONE_NOT_VERIFIED"
    case internalServerError = "INTERNAL_SERVER_ERROR"
    case serverError = "SERVER_ERROR"
    case unknown = "UNKNOWN"
    // Jobs
    case locationRequired = "LOCATION_REQUIRED"
    case invalidParams = "INVALID_PARAMS"
    case geocodeFailed = "GEOCODE_FAILED"
    case jobNotOpen = "JOB_NOT_OPEN"
    case alreadyApplied = "ALREADY_APPLIED"
    case applicationAlreadyProcessed = "APPLICATION_ALREADY_PROCESSED"
    case notFound = "NOT_FOUND"
    case permissionDenied = "PERMISSION_DENIED"

    var userFacingMessage: String {
        switch self {
        case .invalidPhone: return "Please enter a valid phone number."
        case .invalidOTP: return "Invalid verification code. Please try again."
        case .otpExpired: return "Your verification code has expired. Please request a new one."
        case .otpInvalid: return "Incorrect code. Please try again."
        case .otpRateLimit: return "Too many attempts. Please wait before requesting a new code."
        case .otpServiceUnavailable: return "SMS service is temporarily unavailable. Please try again later."
        case .firebaseError: return "Phone verification failed. Please try again."
        case .authenticationError: return "Authentication failed. Please try again."
        case .tokenExpired: return "Your session has expired. Please sign in again."
        case .unauthorized: return "You are not authorised to perform this action."
        case .emailAlreadyVerified: return "This email address is already verified."
        case .emailTokenInvalid: return "The verification link is invalid."
        case .emailTokenExpired: return "The verification link has expired. Please request a new one."
        case .profileAlreadyExists: return "A profile already exists for this account."
        case .profileNotFound: return "Profile not found."
        case .conflict: return "This profile has already been verified and cannot be changed."
        case .validationError: return "Please check the information you entered."
        case .rateLimited: return "You're doing that too fast. Please wait a moment."
        case .invalidFileType: return "Unsupported file format. Please use JPEG, PNG, or WebP."
        case .fileTooLarge: return "File is too large. Maximum size is 5 MB."
        case .uploadFailed: return "Photo upload failed. Please try again."
        case .photoNotFound: return "Photo not found."
        case .phoneNotVerified: return "Please verify your phone number first."
        case .internalServerError: return "Something went wrong on our end. Please try again."
        case .serverError: return "Something went wrong on our end. Please try again."
        case .unknown: return "An unexpected error occurred. Please try again."
        // Jobs
        case .locationRequired: return "Allow location access or enter your postal code."
        case .invalidParams: return "Invalid request parameters."
        case .geocodeFailed: return "Address not found — try a different address or use GPS."
        case .jobNotOpen: return "This job is no longer accepting applications."
        case .alreadyApplied: return "You have already applied for this job."
        case .applicationAlreadyProcessed: return "This application has already been processed."
        case .notFound: return "The requested item could not be found."
        case .permissionDenied: return "You don't have permission to perform this action."
        }
    }
}

// MARK: - App-level Error Type

nonisolated enum AppError: LocalizedError, Sendable {
    case apiError(code: APIErrorCode, message: String)
    case network(underlying: any Error)
    case decoding(underlying: any Error)
    case rateLimited(retryAfter: TimeInterval?)
    case conflict(message: String)
    case serviceUnavailable(message: String)
    case unauthorized
    case unknown

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let msg):
            return msg.isEmpty ? code.userFacingMessage : msg
        case .network:
            return "No internet connection. Please check your network and try again."
        case .decoding:
            return "We received an unexpected response. Please update the app."
        case .rateLimited(let retryAfter):
            if let secs = retryAfter {
                return "Too many requests. Please wait \(Int(secs)) seconds."
            }
            return "Too many requests. Please wait a moment."
        case .conflict(let msg):
            return msg.isEmpty ? "This profile is already verified and cannot be changed." : msg
        case .serviceUnavailable(let msg):
            return msg.isEmpty ? "Service is temporarily unavailable. Please try again later." : msg
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .unknown:
            return "An unexpected error occurred."
        }
    }
}

// MARK: - Auth Request / Response Models

nonisolated struct SendOTPRequest: Encodable, Sendable {
    let phone: String
}

nonisolated struct SendOTPResponse: Decodable, Sendable {
    let message: String?
}

// Firebase id_token flow - includes profile_type
nonisolated struct VerifyOTPFirebaseRequest: Encodable, Sendable {
    let phone: String
    let profile_type: String
    let id_token: String
}

// Dev fallback: plain code - includes profile_type
nonisolated struct VerifyOTPDevRequest: Encodable, Sendable {
    let phone: String
    let profile_type: String
    let code: String
}

nonisolated struct AuthTokenResponse: Decodable, Sendable {
    let access: String
    let refresh: String
}

// verify-otp returns { "data": { "tokens": {...}, "user": {...} } }
nonisolated struct VerifyOTPResponse: Decodable, Sendable {
    let tokens: AuthTokenResponse
    let user: AuthUser
}

// /me/ returns { "data": { "user": {...} } }
nonisolated struct MeResponse: Decodable, Sendable {
    let user: AuthUser
}

// MARK: - Profile Photo

nonisolated struct ProfilePhoto: Decodable, Sendable, Equatable {
    let id: Int
    let status: String
    let url64: String?
    let url256: String?
    let activatedAt: String?
    let version: String?

    var isActive: Bool { status == "active" }
    var isProcessing: Bool { status == "processing" }

    /// Cache-busted URL for 256px avatar display.
    /// Handles both absolute (S3) and relative (local dev) URLs.
    var displayURL: URL? {
        guard let urlString = url256, !urlString.isEmpty else { return nil }
        return resolveURL(urlString)
    }

    /// Cache-busted URL for 64px thumbnail
    var thumbnailURL: URL? {
        guard let urlString = url64, !urlString.isEmpty else { return nil }
        return resolveURL(urlString)
    }

    private func resolveURL(_ urlString: String) -> URL? {
        var fullString: String
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            fullString = urlString
        } else {
            // Relative URL from backend - prepend base URL
            fullString = Config.apiBaseURL.absoluteString + urlString
        }
        if let v = version, !v.isEmpty {
            let separator = fullString.contains("?") ? "&" : "?"
            fullString += "\(separator)v=\(v)"
        }
        return URL(string: fullString)
    }

    enum CodingKeys: String, CodingKey {
        case id, status, version
        case url64 = "url_64"
        case url256 = "url_256"
        case activatedAt = "activated_at"
    }
}

// MARK: - Me / Current User

nonisolated struct AuthUser: Decodable, Sendable, Equatable {
    let id: Int
    let username: String?
    let phone: String?
    let email: String?
    let firstName: String?
    let lastName: String?
    let dateOfBirth: String?
    let isEmailVerified: Bool
    let isActiveProfile: Bool
    let termsAcceptedAt: String?
    let termsVersion: String?
    let workerProfile: AnyCodable?
    let businessProfile: AnyCodable?
    let accessTier: String?
    let phoneVerifiedAt: String?
    let emailVerifiedAt: String?
    let profilePhoto: ProfilePhoto?

    var emailVerified: Bool { isEmailVerified }

    // Profile exists (even if shell/pending with no data)
    var hasWorkerProfile: Bool { workerProfile != nil }
    var hasBusinessProfile: Bool { businessProfile != nil }

    // Profile has actual gov ID data filled in (not just a shell)
    var hasCompleteWorkerProfile: Bool {
        guard let dict = workerProfile?.value as? [String: AnyCodable],
              let govId = dict["gov_id_number"]
        else { return false }
        // gov_id_number must not be null or empty
        if govId.value is NSNull { return false }
        if let str = govId.value as? String { return !str.isEmpty }
        return true
    }

    var hasCompleteBusinessProfile: Bool {
        guard let dict = businessProfile?.value as? [String: AnyCodable],
              let bizId = dict["business_id"]
        else { return false }
        if bizId.value is NSNull { return false }
        if let str = bizId.value as? String { return !str.isEmpty }
        return true
    }

    var hasName: Bool {
        guard let first = firstName, let last = lastName else { return false }
        return first.count >= 2 && last.count >= 2
    }

    var hasDOB: Bool { dateOfBirth != nil && !(dateOfBirth?.isEmpty ?? true) }

    // Backend sends terms_accepted_at as a date string, not a bool
    var hasAcceptedTerms: Bool { termsAcceptedAt != nil }

    enum CodingKeys: String, CodingKey {
        case id, username, phone, email
        case firstName = "first_name"
        case lastName = "last_name"
        case dateOfBirth = "date_of_birth"
        case isEmailVerified = "is_email_verified"
        case isActiveProfile = "is_active_profile"
        case termsAcceptedAt = "terms_accepted_at"
        case termsVersion = "terms_version"
        case workerProfile = "worker_profile"
        case businessProfile = "business_profile"
        case accessTier = "access_tier"
        case phoneVerifiedAt = "phone_verified_at"
        case emailVerifiedAt = "email_verified_at"
        case profilePhoto = "profile_photo"
    }

    static func == (lhs: AuthUser, rhs: AuthUser) -> Bool {
        lhs.id == rhs.id
            && lhs.phone == rhs.phone
            && lhs.email == rhs.email
            && lhs.firstName == rhs.firstName
            && lhs.lastName == rhs.lastName
            && lhs.dateOfBirth == rhs.dateOfBirth
            && lhs.isEmailVerified == rhs.isEmailVerified
            && lhs.isActiveProfile == rhs.isActiveProfile
            && lhs.termsAcceptedAt == rhs.termsAcceptedAt
            && lhs.accessTier == rhs.accessTier
            && lhs.profilePhoto == rhs.profilePhoto
    }
}

// MARK: - Email Verification

nonisolated struct SendEmailVerificationRequest: Encodable, Sendable {
    let email: String
}

nonisolated struct VerifyEmailTokenRequest: Encodable, Sendable {
    let token: String
}

nonisolated struct EmailVerificationResponse: Decodable, Sendable {
    let message: String?
}

// MARK: - Name Update (Step 4 of onboarding)
// PATCH /auth/profile/name/

nonisolated struct NameUpdateRequest: Encodable, Sendable {
    let firstName: String
    let lastName: String

    enum CodingKeys: String, CodingKey {
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

nonisolated struct NameUpdateResponse: Decodable, Sendable {
    let message: String?
}

// MARK: - DOB Update (Step 5 of onboarding)
// PATCH /auth/profile/dob/

nonisolated struct DOBUpdateRequest: Encodable, Sendable {
    let dateOfBirth: String

    enum CodingKeys: String, CodingKey {
        case dateOfBirth = "date_of_birth"
    }
}

nonisolated struct DOBUpdateResponse: Decodable, Sendable {
    let message: String?
}

// MARK: - Terms Accept (Step 6 of onboarding)
// POST /auth/terms/accept/

nonisolated struct TermsAcceptRequest: Encodable, Sendable {
    let accepted: Bool
    let termsVersion: String

    enum CodingKeys: String, CodingKey {
        case accepted
        case termsVersion = "terms_version"
    }
}

nonisolated struct TermsAcceptResponse: Decodable, Sendable {
    let message: String?
}

// MARK: - Profile Create Requests (match exact backend contract)

// Worker: POST /profiles/worker/create/
// Only gov ID fields - name is set via PATCH /auth/profile/name/
nonisolated struct WorkerProfileCreateRequest: Encodable, Sendable {
    let govIdNumber: String
    let govIdType: String

    enum CodingKeys: String, CodingKey {
        case govIdNumber = "gov_id_number"
        case govIdType = "gov_id_type"
    }
}

// Business: POST /profiles/business/create/
nonisolated struct BusinessProfileCreateRequest: Encodable, Sendable {
    let businessId: String
    let businessName: String
    let managerGovIdNumber: String

    enum CodingKeys: String, CodingKey {
        case businessId = "business_id"
        case businessName = "business_name"
        case managerGovIdNumber = "manager_gov_id_number"
    }
}

nonisolated struct ProfileCreateResponse: Decodable, Sendable {
    let message: String?
}

// MARK: - Profile Status

nonisolated struct ProfileStatus: Decodable, Sendable {
    let workerStatus: String?
    let businessStatus: String?
    let isActiveProfile: Bool
    let accessTier: String
    let verificationStatus: String?

    var hasWorkerProfile: Bool { workerStatus != nil }
    var hasBusinessProfile: Bool { businessStatus != nil }

    // Profile is pending verification
    var isWorkerPending: Bool { workerStatus?.lowercased() == "pending" }
    var isBusinessPending: Bool { businessStatus?.lowercased() == "pending" }

    // Profile is approved
    var isWorkerApproved: Bool { workerStatus?.lowercased() == "approved" }
    var isBusinessApproved: Bool { businessStatus?.lowercased() == "approved" }

    // Profile was rejected - can resubmit
    var isWorkerRejected: Bool { workerStatus?.lowercased() == "rejected" }
    var isBusinessRejected: Bool { businessStatus?.lowercased() == "rejected" }

    enum CodingKeys: String, CodingKey {
        case workerStatus = "worker_status"
        case businessStatus = "business_status"
        case isActiveProfile = "is_active_profile"
        case accessTier = "access_tier"
        case verificationStatus = "verification_status"
    }
}

nonisolated struct AccessTier: Decodable, Sendable {
    let accessTier: String

    enum CodingKeys: String, CodingKey {
        case accessTier = "access_tier"
    }
}

// MARK: - Profile Photo Upload

nonisolated struct PhotoUploadURLRequest: Encodable, Sendable {
    let fileName: String
    let contentType: String
    let sizeBytes: Int
    let sha256: String?

    enum CodingKeys: String, CodingKey {
        case fileName = "file_name"
        case contentType = "content_type"
        case sizeBytes = "size_bytes"
        case sha256
    }
}

nonisolated struct PhotoUploadURLResponse: Decodable, Sendable {
    let photoId: Int
    let upload: S3UploadInfo

    enum CodingKeys: String, CodingKey {
        case photoId = "photo_id"
        case upload
    }
}

nonisolated struct S3UploadInfo: Decodable, Sendable {
    let method: String
    let url: String
    let fields: [String: String]
    let expiresInSeconds: Int

    enum CodingKeys: String, CodingKey {
        case method, url, fields
        case expiresInSeconds = "expires_in_seconds"
    }
}

nonisolated struct PhotoConfirmRequest: Encodable, Sendable {
    let photoId: Int

    enum CodingKeys: String, CodingKey {
        case photoId = "photo_id"
    }
}

nonisolated struct PhotoConfirmResponse: Decodable, Sendable {
    let profilePhoto: ProfilePhoto
    let user: AuthUser?

    enum CodingKeys: String, CodingKey {
        case profilePhoto = "profile_photo"
        case user
    }
}

// MARK: - Jobs API Models

// MARK: Job (returned by POST /jobs/ and GET /jobs/nearby/)
nonisolated struct APIJob: Decodable, Sendable, Identifiable, Equatable {
    let id: Int
    let clientId: Int
    let title: String
    let description: String?
    let addressDisplay: String?
    let status: String            // "open" | "filled" | "cancelled" | "completed"
    let payRate: String           // decimal string, e.g. "18.50"
    let scheduledStart: Date
    let scheduledEnd: Date?
    let distanceKm: Double?
    let createdAt: Date

    var statusEnum: JobStatus { JobStatus(rawValue: status) ?? .open }

    /// Returns a copy of this job with a different status (used for local state mutations).
    func withStatus(_ newStatus: JobStatus) -> APIJob {
        APIJob(
            id: id, clientId: clientId, title: title, description: description,
            addressDisplay: addressDisplay, status: newStatus.rawValue, payRate: payRate,
            scheduledStart: scheduledStart, scheduledEnd: scheduledEnd,
            distanceKm: distanceKm, createdAt: createdAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case clientId = "client_id"
        case title, description, status
        case addressDisplay = "address_display"
        case payRate = "pay_rate"
        case scheduledStart = "scheduled_start"
        case scheduledEnd = "scheduled_end"
        case distanceKm = "distance_km"
        case createdAt = "created_at"
    }
}

// MARK: Job Status
nonisolated enum JobStatus: String, Sendable, CaseIterable {
    case open       = "open"
    case filled     = "filled"
    case cancelled  = "cancelled"
    case completed  = "completed"
}

// MARK: Application Status
nonisolated enum ApplicationStatus: String, Sendable, CaseIterable {
    case pending  = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
}

// MARK: Worker Verification Status (returned in nearby workers / applications)
nonisolated enum WorkerVerificationStatus: String, Sendable {
    case pending          = "pending"
    case instantVerified  = "instant_verified"
    case pendingManual    = "pending_manual"
    case approvedManual   = "approved_manual"
    case rejected         = "rejected"
}

// MARK: Nearby Worker (GET /jobs/{id}/workers/)
nonisolated struct NearbyWorker: Decodable, Sendable, Identifiable, Equatable {
    let id: Int
    let firstName: String
    let lastName: String
    let verificationStatus: String
    let distanceKm: Double?
    let photoUrl: String?

    var displayName: String { "\(firstName) \(lastName)" }
    var verificationStatusEnum: WorkerVerificationStatus {
        WorkerVerificationStatus(rawValue: verificationStatus) ?? .pending
    }

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName  = "last_name"
        case verificationStatus = "verification_status"
        case distanceKm = "distance_km"
        case photoUrl   = "photo_url"
    }
}

// MARK: Application (GET /jobs/{id}/applications/ & POST /jobs/{id}/apply/)
nonisolated struct JobApplication: Decodable, Sendable, Identifiable, Equatable {
    let id: Int
    let workerId: Int
    let firstName: String
    let lastName: String
    let verificationStatus: String
    let coverNote: String?
    let status: String           // "pending" | "accepted" | "rejected"
    let createdAt: Date

    var displayName: String { "\(firstName) \(lastName)" }
    var statusEnum: ApplicationStatus { ApplicationStatus(rawValue: status) ?? .pending }
    var verificationStatusEnum: WorkerVerificationStatus {
        WorkerVerificationStatus(rawValue: verificationStatus) ?? .pending
    }

    /// Returns a copy with a different status (used for local state mutations after hire).
    func withStatus(_ newStatus: ApplicationStatus) -> JobApplication {
        JobApplication(
            id: id, workerId: workerId, firstName: firstName, lastName: lastName,
            verificationStatus: verificationStatus, coverNote: coverNote,
            status: newStatus.rawValue, createdAt: createdAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case workerId = "worker_id"
        case firstName = "first_name"
        case lastName  = "last_name"
        case verificationStatus = "verification_status"
        case coverNote  = "cover_note"
        case status
        case createdAt  = "created_at"
    }
}

// MARK: - Jobs Request / Response Wrappers

// POST /api/v1/jobs/
nonisolated struct PostJobRequest: Encodable, Sendable {
    let title: String
    let description: String?
    let payRate: String          // decimal string
    let scheduledStart: Date
    let scheduledEnd: Date?
    let lat: Double?
    let lng: Double?
    let address: String?

    enum CodingKeys: String, CodingKey {
        case title, description
        case payRate       = "pay_rate"
        case scheduledStart = "scheduled_start"
        case scheduledEnd   = "scheduled_end"
        case lat, lng, address
    }
}

nonisolated struct PostJobResponse: Decodable, Sendable {
    let job: APIJob
}

// GET /api/v1/jobs/nearby/
nonisolated struct NearbyJobsResponse: Decodable, Sendable {
    let count: Int
    let jobs: [APIJob]
}

// GET /api/v1/jobs/{id}/workers/
nonisolated struct NearbyWorkersResponse: Decodable, Sendable {
    let count: Int
    let workers: [NearbyWorker]
}

// POST /api/v1/jobs/{id}/apply/
nonisolated struct ApplyForJobRequest: Encodable, Sendable {
    let coverNote: String?

    enum CodingKeys: String, CodingKey {
        case coverNote = "cover_note"
    }
}

nonisolated struct ApplyForJobResponse: Decodable, Sendable {
    let application: JobApplication
}

// GET /api/v1/jobs/{jobId}/applications/
nonisolated struct JobApplicationsResponse: Decodable, Sendable {
    let count: Int
    let applications: [JobApplication]
}

// POST /api/v1/jobs/{id}/hire/{app_id}/
nonisolated struct HireWorkerResponse: Decodable, Sendable {
    let application: JobApplication
}

// MARK: - My Applications (Worker)
// GET /api/v1/my/applications/?status=pending|accepted|rejected
// Each item embeds a job summary as returned by the backend.
// NOTE: job.scheduled_end and job.client_id are NOT included in this response.
// NOTE: distance_km is always null here — only populated on nearby search results.

nonisolated struct MyApplicationItem: Decodable, Sendable, Identifiable, Equatable {
    let id: Int                     // application id
    let status: String              // "pending" | "accepted" | "rejected"
    let coverNote: String?
    let createdAt: Date
    let updatedAt: Date
    let job: MyApplicationJob

    var statusEnum: ApplicationStatus { ApplicationStatus(rawValue: status) ?? .pending }

    enum CodingKeys: String, CodingKey {
        case id, status
        case coverNote  = "cover_note"
        case createdAt  = "created_at"
        case updatedAt  = "updated_at"
        case job
    }
}

/// Job summary as embedded inside GET /api/v1/my/applications/
/// Fields are a strict subset of APIJob — scheduled_end and client_id are NOT returned here.
nonisolated struct MyApplicationJob: Decodable, Sendable, Equatable {
    let id: Int
    let title: String
    let status: String              // job status: "open" | "filled" | "cancelled" | "completed"
    let payRate: String
    let scheduledStart: Date
    let addressDisplay: String?

    var jobStatusEnum: JobStatus { JobStatus(rawValue: status) ?? .open }

    enum CodingKeys: String, CodingKey {
        case id, title, status
        case payRate        = "pay_rate"
        case scheduledStart = "scheduled_start"
        case addressDisplay = "address_display"
    }
}

nonisolated struct MyApplicationsResponse: Decodable, Sendable {
    let count: Int
    let applications: [MyApplicationItem]
}

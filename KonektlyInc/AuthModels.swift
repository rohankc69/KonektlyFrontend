//
//  AuthModels.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import Foundation
import CoreLocation

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
    // Account Deletion
    case phoneMismatch = "PHONE_MISMATCH"
    case deletionBlocked = "DELETION_BLOCKED"
    case alreadyScheduled = "ALREADY_SCHEDULED"
    case accountPurged = "ACCOUNT_PURGED"
    // Jobs
    case locationRequired = "LOCATION_REQUIRED"
    case invalidParams = "INVALID_PARAMS"
    case geocodeFailed = "GEOCODE_FAILED"
    case jobNotOpen = "JOB_NOT_OPEN"
    case alreadyApplied = "ALREADY_APPLIED"
    case applicationAlreadyProcessed = "APPLICATION_ALREADY_PROCESSED"
    case notFound = "NOT_FOUND"
    case permissionDenied = "PERMISSION_DENIED"
    // Reviews
    case jobNotCompleted = "JOB_NOT_COMPLETED"
    case alreadyReviewed = "ALREADY_REVIEWED"
    case notAParticipant = "NOT_A_PARTICIPANT"
    case reviewWindowExpired = "REVIEW_WINDOW_EXPIRED"
    case noCompletedShift = "NO_COMPLETED_SHIFT"
    // Experience
    case maxExperiencesReached = "MAX_EXPERIENCES_REACHED"

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
        case .invalidFileType: return "Unsupported file format. Please use JPEG, PNG, WebP, HEIC, or HEIF."
        case .fileTooLarge: return "File is too large. Maximum size is 5 MB."
        case .uploadFailed: return "Photo upload failed. Please try again."
        case .photoNotFound: return "Photo not found."
        case .phoneNotVerified: return "Please verify your phone number first."
        case .internalServerError: return "Something went wrong on our end. Please try again."
        case .serverError: return "Something went wrong on our end. Please try again."
        case .unknown: return "An unexpected error occurred. Please try again."
        // Account Deletion
        case .phoneMismatch: return "The phone number you entered doesn't match your account."
        case .deletionBlocked: return "Your account can't be deleted right now. Please resolve outstanding items first."
        case .alreadyScheduled: return "Your account deletion is already scheduled."
        case .accountPurged: return "This account has been permanently deleted."
        // Jobs
        case .locationRequired: return "Allow location access or enter your postal code."
        case .invalidParams: return "Invalid request parameters."
        case .geocodeFailed: return "Address not found — try a different address or use GPS."
        case .jobNotOpen: return "This job is no longer accepting applications."
        case .alreadyApplied: return "You have already applied for this job."
        case .applicationAlreadyProcessed: return "This application has already been processed."
        case .notFound: return "The requested item could not be found."
        case .permissionDenied: return "You don't have permission to perform this action."
        // Reviews
        case .jobNotCompleted: return "This job must be completed before you can leave a review."
        case .alreadyReviewed: return "You've already reviewed this job."
        case .notAParticipant: return "You are not a participant in this job."
        case .reviewWindowExpired: return "The review period for this job has expired."
        case .noCompletedShift: return "No completed shift record found for this job."
        // Experience
        case .maxExperiencesReached: return "You've reached the maximum of 20 experience entries."
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
        case .network(let underlying):
            if let urlError = underlying as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    return "No internet connection. Please check your network and try again."
                case .timedOut:
                    return "Request timed out. Please try again."
                case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                    return "Could not reach the server. Please try again."
                case .networkConnectionLost:
                    return "Connection was lost. Please try again."
                default:
                    return "Network error. Please check your connection and try again."
                }
            }
            return "Network error. Please check your connection and try again."
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
    let privacyAcceptedAt: String?
    let privacyVersion: String?
    let profilePhoto: ProfilePhoto?

    var emailVerified: Bool { isEmailVerified }
    var hasAcceptedPrivacy: Bool { privacyAcceptedAt != nil }

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
        case privacyAcceptedAt = "privacy_accepted_at"
        case privacyVersion = "privacy_version"
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
            && lhs.privacyAcceptedAt == rhs.privacyAcceptedAt
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

// MARK: - Terms Document (GET /api/v1/legal/terms/)
// Fetched before showing TermsAcceptView — version from this response MUST be sent in the accept call.
// No authentication required.

nonisolated struct TermsDocument: Decodable, Sendable {
    let id: Int
    let version: String       // e.g. "1.0" — pass this to POST /auth/terms/accept/
    let title: String
    let content: String
    let effectiveDate: String // "YYYY-MM-DD" display string
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, version, title, content
        case effectiveDate = "effective_date"
        case createdAt     = "created_at"
    }
}

// MARK: - Terms Accept (Step 6 of onboarding)
// POST /api/v1/auth/terms/accept/

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
    /// Ordered key-value pairs — S3 presigned POST requires fields in the order the backend provides them.
    let orderedFields: [(key: String, value: String)]
    /// Dictionary accessor for quick lookups / emptiness checks.
    var fields: [String: String] {
        Dictionary(orderedFields.map { ($0.key, $0.value) }, uniquingKeysWith: { _, last in last })
    }
    let expiresInSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case method, url, fields
        case expiresInSeconds = "expires_in_seconds"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = try container.decode(String.self, forKey: .url)

        // Decode fields preserving JSON key order using JSONSerialization
        // JSONDecoder's [String: String] uses Dictionary which loses order.
        var ordered: [(key: String, value: String)] = []
        if container.contains(.fields) {
            // Try to get the raw JSON to preserve order
            let fieldsDict = try container.decodeIfPresent([String: String].self, forKey: .fields) ?? [:]
            // Align with AWS SigV4 POST example order (algorithm before credential).
            // Wrong order can break signature verification for some policies.
            let preferredOrder = [
                "key", "policy", "x-amz-algorithm", "x-amz-credential",
                "x-amz-date", "x-amz-signature", "x-amz-security-token",
                "Content-Type", "content-type", "success_action_status",
                "acl", "x-amz-meta-photo-id"
            ]
            // Add fields in preferred order first, then any remaining
            var added = Set<String>()
            for key in preferredOrder {
                if let val = fieldsDict[key] {
                    ordered.append((key: key, value: val))
                    added.insert(key)
                }
            }
            for (key, val) in fieldsDict where !added.contains(key) {
                ordered.append((key: key, value: val))
            }
        }
        orderedFields = ordered

        method = try container.decodeIfPresent(String.self, forKey: .method) ?? (ordered.isEmpty ? "PUT" : "POST")
        expiresInSeconds = try container.decodeIfPresent(Int.self, forKey: .expiresInSeconds)
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
    let distanceM: Double?
    let createdAt: Date
    
    // MARK: - Location Privacy / Blurring Support
    /// Optional coordinates for the job location (may be approximate if locationIsApproximate is true)
    let lat: Double?
    let lng: Double?
    /// Indicates whether the coordinates are blurred/approximate for privacy
    /// When true, lat/lng represent an approximate location (e.g., offset by 100-500m)
    let locationIsApproximate: Bool?

    // Business info (optional, included in nearby/detail responses)
    let clientName: String?
    let clientLogoUrl: String?
    let clientAvgRating: String?
    let clientReviewCount: Int?

    var statusEnum: JobStatus { JobStatus(rawValue: status) ?? .open }
    
    /// Returns the coordinate for map display.
    /// If lat/lng are available, use them; otherwise returns nil.
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = lat, let lng = lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Formatted distance badge per spec:
    /// null  → nil (hide badge entirely)
    /// < 1000 m → "800 m"
    /// ≥ 1000 m → "2.3 km"
    var formattedDistance: String? {
        guard let m = distanceM else {
            // Fall back to distanceKm if only km is present (legacy)
            guard let km = distanceKm else { return nil }
            return String(format: "%.1f km", km)
        }
        if m < 1000 { return "\(Int(m.rounded())) m" }
        guard let km = distanceKm else { return String(format: "%.1f km", m / 1000) }
        return String(format: "%.1f km", km)
    }

    init(
        id: Int,
        clientId: Int,
        title: String,
        description: String?,
        addressDisplay: String?,
        status: String,
        payRate: String,
        scheduledStart: Date,
        scheduledEnd: Date?,
        distanceKm: Double?,
        distanceM: Double?,
        createdAt: Date,
        lat: Double?,
        lng: Double?,
        locationIsApproximate: Bool?,
        clientName: String?,
        clientLogoUrl: String?,
        clientAvgRating: String?,
        clientReviewCount: Int?
    ) {
        self.id = id
        self.clientId = clientId
        self.title = title
        self.description = description
        self.addressDisplay = addressDisplay
        self.status = status
        self.payRate = payRate
        self.scheduledStart = scheduledStart
        self.scheduledEnd = scheduledEnd
        self.distanceKm = distanceKm
        self.distanceM = distanceM
        self.createdAt = createdAt
        self.lat = lat
        self.lng = lng
        self.locationIsApproximate = locationIsApproximate
        self.clientName = clientName
        self.clientLogoUrl = clientLogoUrl
        self.clientAvgRating = clientAvgRating
        self.clientReviewCount = clientReviewCount
    }

    /// Returns a copy of this job with a different status (used for local state mutations).
    func withStatus(_ newStatus: JobStatus) -> APIJob {
        APIJob(
            id: id, clientId: clientId, title: title, description: description,
            addressDisplay: addressDisplay, status: newStatus.rawValue, payRate: payRate,
            scheduledStart: scheduledStart, scheduledEnd: scheduledEnd,
            distanceKm: distanceKm, distanceM: distanceM, createdAt: createdAt,
            lat: lat, lng: lng, locationIsApproximate: locationIsApproximate,
            clientName: clientName, clientLogoUrl: clientLogoUrl,
            clientAvgRating: clientAvgRating, clientReviewCount: clientReviewCount
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
        case distanceM  = "distance_m"
        case createdAt = "created_at"
        case lat, lng
        case locationIsApproximate = "location_is_approximate"
        case clientName = "client_name"
        case clientLogoUrl = "client_logo_url"
        case clientAvgRating = "client_avg_rating"
        case clientReviewCount = "client_review_count"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decode(Int.self, forKey: .id)
        clientId = try c.decode(Int.self, forKey: .clientId)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        addressDisplay = try c.decodeIfPresent(String.self, forKey: .addressDisplay)
        status = try c.decode(String.self, forKey: .status)

        if let value = try? c.decodeIfPresent(String.self, forKey: .payRate) {
            payRate = value
        } else if let value = try? c.decodeIfPresent(Double.self, forKey: .payRate) {
            payRate = String(value)
        } else if let value = try? c.decodeIfPresent(Int.self, forKey: .payRate) {
            payRate = String(value)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .payRate, in: c, debugDescription: "pay_rate missing")
        }

        scheduledStart = try c.decode(Date.self, forKey: .scheduledStart)
        scheduledEnd = try c.decodeIfPresent(Date.self, forKey: .scheduledEnd)
        createdAt = try c.decode(Date.self, forKey: .createdAt)

        if let value = try? c.decodeIfPresent(Double.self, forKey: .lat) {
            lat = value
        } else if let value = try? c.decodeIfPresent(Int.self, forKey: .lat) {
            lat = Double(value)
        } else if let value = try? c.decodeIfPresent(String.self, forKey: .lat) {
            lat = Double(value)
        } else {
            lat = nil
        }

        if let value = try? c.decodeIfPresent(Double.self, forKey: .lng) {
            lng = value
        } else if let value = try? c.decodeIfPresent(Int.self, forKey: .lng) {
            lng = Double(value)
        } else if let value = try? c.decodeIfPresent(String.self, forKey: .lng) {
            lng = Double(value)
        } else {
            lng = nil
        }

        if let value = try? c.decodeIfPresent(Double.self, forKey: .distanceKm) {
            distanceKm = value
        } else if let value = try? c.decodeIfPresent(Int.self, forKey: .distanceKm) {
            distanceKm = Double(value)
        } else if let value = try? c.decodeIfPresent(String.self, forKey: .distanceKm) {
            distanceKm = Double(value)
        } else {
            distanceKm = nil
        }

        if let value = try? c.decodeIfPresent(Double.self, forKey: .distanceM) {
            distanceM = value
        } else if let value = try? c.decodeIfPresent(Int.self, forKey: .distanceM) {
            distanceM = Double(value)
        } else if let value = try? c.decodeIfPresent(String.self, forKey: .distanceM) {
            distanceM = Double(value)
        } else {
            distanceM = nil
        }
        locationIsApproximate = try c.decodeIfPresent(Bool.self, forKey: .locationIsApproximate)

        clientName = try c.decodeIfPresent(String.self, forKey: .clientName)
        clientLogoUrl = try c.decodeIfPresent(String.self, forKey: .clientLogoUrl)
        if let value = try? c.decodeIfPresent(Int.self, forKey: .clientReviewCount) {
            clientReviewCount = value
        } else if let value = try? c.decodeIfPresent(String.self, forKey: .clientReviewCount) {
            clientReviewCount = Int(value)
        } else {
            clientReviewCount = nil
        }
        if let value = try? c.decodeIfPresent(String.self, forKey: .clientAvgRating) {
            clientAvgRating = value
        } else if let value = try? c.decodeIfPresent(Double.self, forKey: .clientAvgRating) {
            clientAvgRating = String(value)
        } else if let value = try? c.decodeIfPresent(Int.self, forKey: .clientAvgRating) {
            clientAvgRating = String(value)
        } else {
            clientAvgRating = nil
        }
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
    let headline: String?
    let avgRating: String?
    let reviewCount: Int?
    let skills: [SkillSummary]?

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
        case headline
        case avgRating = "avg_rating"
        case reviewCount = "review_count"
        case skills
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        firstName = try c.decode(String.self, forKey: .firstName)
        lastName = try c.decode(String.self, forKey: .lastName)
        verificationStatus = try c.decode(String.self, forKey: .verificationStatus)
        photoUrl = try c.decodeIfPresent(String.self, forKey: .photoUrl)
        headline = try c.decodeIfPresent(String.self, forKey: .headline)
        skills = try c.decodeIfPresent([SkillSummary].self, forKey: .skills)

        if let value = try? c.decodeIfPresent(Double.self, forKey: .distanceKm) {
            distanceKm = value
        } else if let value = try? c.decodeIfPresent(Int.self, forKey: .distanceKm) {
            distanceKm = Double(value)
        } else if let value = try? c.decodeIfPresent(String.self, forKey: .distanceKm) {
            distanceKm = Double(value)
        } else {
            distanceKm = nil
        }

        if let value = try? c.decodeIfPresent(Int.self, forKey: .reviewCount) {
            reviewCount = value
        } else if let value = try? c.decodeIfPresent(String.self, forKey: .reviewCount),
                  let parsed = Int(value) {
            reviewCount = parsed
        } else {
            reviewCount = nil
        }

        if let value = try? c.decodeIfPresent(String.self, forKey: .avgRating) {
            avgRating = value
        } else if let value = try? c.decodeIfPresent(Double.self, forKey: .avgRating) {
            avgRating = String(value)
        } else if let value = try? c.decodeIfPresent(Int.self, forKey: .avgRating) {
            avgRating = String(value)
        } else {
            avgRating = nil
        }
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
    let headline: String?
    let avgRating: String?
    let reviewCount: Int?
    let skills: [SkillSummary]?
    let photoUrl: String?

    var displayName: String { "\(firstName) \(lastName)" }
    var statusEnum: ApplicationStatus { ApplicationStatus(rawValue: status) ?? .pending }
    var verificationStatusEnum: WorkerVerificationStatus {
        WorkerVerificationStatus(rawValue: verificationStatus) ?? .pending
    }

    init(
        id: Int,
        workerId: Int,
        firstName: String,
        lastName: String,
        verificationStatus: String,
        coverNote: String?,
        status: String,
        createdAt: Date,
        headline: String?,
        avgRating: String?,
        reviewCount: Int?,
        skills: [SkillSummary]?,
        photoUrl: String?
    ) {
        self.id = id
        self.workerId = workerId
        self.firstName = firstName
        self.lastName = lastName
        self.verificationStatus = verificationStatus
        self.coverNote = coverNote
        self.status = status
        self.createdAt = createdAt
        self.headline = headline
        self.avgRating = avgRating
        self.reviewCount = reviewCount
        self.skills = skills
        self.photoUrl = photoUrl
    }

    /// Returns a copy with a different status (used for local state mutations after hire).
    func withStatus(_ newStatus: ApplicationStatus) -> JobApplication {
        JobApplication(
            id: id, workerId: workerId, firstName: firstName, lastName: lastName,
            verificationStatus: verificationStatus, coverNote: coverNote,
            status: newStatus.rawValue, createdAt: createdAt,
            headline: headline, avgRating: avgRating, reviewCount: reviewCount,
            skills: skills, photoUrl: photoUrl
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
        case headline
        case avgRating = "avg_rating"
        case reviewCount = "review_count"
        case skills
        case photoUrl = "photo_url"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        workerId = try c.decode(Int.self, forKey: .workerId)
        firstName = try c.decode(String.self, forKey: .firstName)
        lastName = try c.decode(String.self, forKey: .lastName)
        verificationStatus = try c.decode(String.self, forKey: .verificationStatus)
        coverNote = try c.decodeIfPresent(String.self, forKey: .coverNote)
        status = try c.decode(String.self, forKey: .status)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        headline = try c.decodeIfPresent(String.self, forKey: .headline)
        skills = try c.decodeIfPresent([SkillSummary].self, forKey: .skills)
        photoUrl = try c.decodeIfPresent(String.self, forKey: .photoUrl)

        if let value = try? c.decodeIfPresent(Int.self, forKey: .reviewCount) {
            reviewCount = value
        } else if let value = try? c.decodeIfPresent(String.self, forKey: .reviewCount),
                  let parsed = Int(value) {
            reviewCount = parsed
        } else {
            reviewCount = nil
        }

        if let value = try? c.decodeIfPresent(String.self, forKey: .avgRating) {
            avgRating = value
        } else if let value = try? c.decodeIfPresent(Double.self, forKey: .avgRating) {
            avgRating = String(value)
        } else if let value = try? c.decodeIfPresent(Int.self, forKey: .avgRating) {
            avgRating = String(value)
        } else {
            avgRating = nil
        }
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
nonisolated struct JobDetailResponse: Decodable, Sendable {
    let job: APIJob
}

nonisolated struct NearbyJobsResponse: Decodable, Sendable {
    let count: Int
    let jobs: [APIJob]

    enum CodingKeys: String, CodingKey {
        case count, jobs, results
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let parsedCount = try c.decodeIfPresent(Int.self, forKey: .count) {
            count = parsedCount
        } else if let parsedCount = try c.decodeIfPresent(String.self, forKey: .count), let n = Int(parsedCount) {
            count = n
        } else {
            count = 0
        }
        if let decodedJobs = try c.decodeIfPresent([APIJob].self, forKey: .jobs) {
            jobs = decodedJobs
        } else if let decodedResults = try c.decodeIfPresent([APIJob].self, forKey: .results) {
            jobs = decodedResults
        } else {
            jobs = []
        }
    }
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

    enum CodingKeys: String, CodingKey {
        case count, applications, results
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let parsedCount = try c.decodeIfPresent(Int.self, forKey: .count) {
            count = parsedCount
        } else if let parsedCount = try c.decodeIfPresent(String.self, forKey: .count), let n = Int(parsedCount) {
            count = n
        } else {
            count = 0
        }

        if let decodedApplications = try c.decodeIfPresent([JobApplication].self, forKey: .applications) {
            applications = decodedApplications
        } else if let decodedResults = try c.decodeIfPresent([JobApplication].self, forKey: .results) {
            applications = decodedResults
        } else {
            applications = []
        }
    }
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
    let id: Int
    let status: String
    let coverNote: String?
    let createdAt: Date
    let updatedAt: Date
    let job: MyApplicationJob

    var statusEnum: ApplicationStatus { ApplicationStatus(rawValue: status) ?? .pending }

    init(id: Int, status: String, coverNote: String?, createdAt: Date, updatedAt: Date, job: MyApplicationJob) {
        self.id = id; self.status = status; self.coverNote = coverNote
        self.createdAt = createdAt; self.updatedAt = updatedAt; self.job = job
    }

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
    let status: String
    let payRate: String
    let scheduledStart: Date
    let addressDisplay: String?
    let distanceKm: Double?
    let distanceM: Double?

    var jobStatusEnum: JobStatus { JobStatus(rawValue: status) ?? .open }

    var formattedDistance: String? {
        guard let m = distanceM else {
            guard let km = distanceKm else { return nil }
            return String(format: "%.1f km", km)
        }
        if m < 1000 { return "\(Int(m.rounded())) m" }
        guard let km = distanceKm else { return String(format: "%.1f km", m / 1000) }
        return String(format: "%.1f km", km)
    }

    init(id: Int, title: String, status: String, payRate: String,
         scheduledStart: Date, addressDisplay: String?,
         distanceKm: Double?, distanceM: Double?) {
        self.id = id; self.title = title; self.status = status; self.payRate = payRate
        self.scheduledStart = scheduledStart; self.addressDisplay = addressDisplay
        self.distanceKm = distanceKm; self.distanceM = distanceM
    }

    enum CodingKeys: String, CodingKey {
        case id, title, status
        case payRate        = "pay_rate"
        case scheduledStart = "scheduled_start"
        case addressDisplay = "address_display"
        case distanceKm     = "distance_km"
        case distanceM      = "distance_m"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        status = try c.decode(String.self, forKey: .status)
        scheduledStart = try c.decode(Date.self, forKey: .scheduledStart)
        addressDisplay = try c.decodeIfPresent(String.self, forKey: .addressDisplay)

        if let value = try? c.decodeIfPresent(String.self, forKey: .payRate) {
            payRate = value
        } else if let value = try? c.decodeIfPresent(Double.self, forKey: .payRate) {
            payRate = String(value)
        } else if let value = try? c.decodeIfPresent(Int.self, forKey: .payRate) {
            payRate = String(value)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .payRate, in: c, debugDescription: "pay_rate missing")
        }

        if let value = try? c.decodeIfPresent(Double.self, forKey: .distanceKm) {
            distanceKm = value
        } else if let value = try? c.decodeIfPresent(Int.self, forKey: .distanceKm) {
            distanceKm = Double(value)
        } else if let value = try? c.decodeIfPresent(String.self, forKey: .distanceKm) {
            distanceKm = Double(value)
        } else {
            distanceKm = nil
        }

        if let value = try? c.decodeIfPresent(Double.self, forKey: .distanceM) {
            distanceM = value
        } else if let value = try? c.decodeIfPresent(Int.self, forKey: .distanceM) {
            distanceM = Double(value)
        } else if let value = try? c.decodeIfPresent(String.self, forKey: .distanceM) {
            distanceM = Double(value)
        } else {
            distanceM = nil
        }
    }
}

nonisolated struct MyApplicationsResponse: Decodable, Sendable {
    let count: Int
    let applications: [MyApplicationItem]

    enum CodingKeys: String, CodingKey {
        case count, applications, results
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let parsedCount = try c.decodeIfPresent(Int.self, forKey: .count) {
            count = parsedCount
        } else if let parsedCount = try c.decodeIfPresent(String.self, forKey: .count), let n = Int(parsedCount) {
            count = n
        } else {
            count = 0
        }
        if let decodedApplications = try c.decodeIfPresent([MyApplicationItem].self, forKey: .applications) {
            applications = decodedApplications
        } else if let decodedResults = try c.decodeIfPresent([MyApplicationItem].self, forKey: .results) {
            applications = decodedResults
        } else {
            applications = []
        }
    }
}

/// Used for endpoints that return a 200 with no meaningful data body (e.g. complete job).
/// Named distinctly from APIClient's internal EmptyResponse to avoid shadowing.
nonisolated struct VoidAPIResponse: Decodable, Sendable {}

// MARK: - Messaging API Models

/// Conversation as returned by GET /api/v1/messages/conversations/
nonisolated struct APIConversation: Decodable, Sendable, Identifiable, Equatable {
    let id: UUID
    let job: Int
    let jobTitle: String
    let jobStatus: String
    let otherUserId: String
    let otherUserName: String
    let isLocked: Bool
    let lockedAt: String?
    let isMuted: Bool?
    let mutedUntil: String?
    let unreadCount: Int
    let lastMessage: APIMessagePreview?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, job
        case jobTitle = "job_title"
        case jobStatus = "job_status"
        case otherUserId = "other_user_id"
        case otherUserName = "other_user_name"
        case isLocked = "is_locked"
        case lockedAt = "locked_at"
        case isMuted = "is_muted"
        case mutedUntil = "muted_until"
        case unreadCount = "unread_count"
        case lastMessage = "last_message"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    static func == (lhs: APIConversation, rhs: APIConversation) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt && lhs.unreadCount == rhs.unreadCount
    }
}

/// Last message preview embedded in conversation list
nonisolated struct APIMessagePreview: Decodable, Sendable, Equatable {
    let id: String
    let body: String
    let senderId: String
    let createdAt: Date
    let isRead: Bool

    enum CodingKeys: String, CodingKey {
        case id, body
        case senderId = "sender_id"
        case createdAt = "created_at"
        case isRead = "is_read"
    }
}

/// Single chat message as returned by GET /api/v1/messages/conversations/<id>/
nonisolated struct APIChatMessage: Decodable, Sendable, Identifiable, Equatable {
    let id: UUID
    let conversation: UUID
    let sender: Int
    let senderName: String
    let body: String
    let isRead: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, conversation, sender, body
        case senderName = "sender_name"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

// MARK: - Start Conversation (Pre-Hire Chat)

nonisolated struct StartConversationRequest: Encodable, Sendable {
    let applicationId: Int

    enum CodingKeys: String, CodingKey {
        case applicationId = "application_id"
    }
}

nonisolated struct StartConversationResponse: Decodable, Sendable {
    let conversationId: UUID
    let created: Bool
    let isLocked: Bool

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case created
        case isLocked = "is_locked"
    }
}

// MARK: Messaging API Responses

nonisolated struct ConversationsListResponse: Decodable, Sendable {
    let count: Int
    let conversations: [APIConversation]
}

nonisolated struct ConversationMessagesResponse: Decodable, Sendable {
    let conversationId: UUID
    let isLocked: Bool
    let hasMore: Bool
    let messages: [APIChatMessage]

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case isLocked = "is_locked"
        case hasMore = "has_more"
        case messages
    }
}

nonisolated struct UnreadCountResponse: Decodable, Sendable {
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case unreadCount = "unread_count"
    }
}

nonisolated struct DeviceRegisterRequest: Encodable, Sendable {
    let token: String
    let platform: String
}

nonisolated struct DeviceRegisterResponse: Decodable, Sendable {
    let deviceId: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
    }
}

nonisolated struct DeviceUnregisterRequest: Encodable, Sendable {
    let token: String
}

// MARK: - Block / Report API Models

nonisolated struct BlockedUser: Decodable, Sendable, Identifiable, Equatable {
    let id: Int
    let userId: Int
    let firstName: String?
    let lastName: String?
    let blockedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case blockedAt = "blocked_at"
    }

    var displayName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
}

nonisolated struct BlockedUsersResponse: Decodable, Sendable {
    let blockedUsers: [BlockedUser]

    enum CodingKeys: String, CodingKey {
        case blockedUsers = "blocked_users"
    }
}

nonisolated struct BlockUserResponse: Decodable, Sendable {
    let message: String?
}

nonisolated struct ReportRequest: Encodable, Sendable {
    let reason: String
    let messageId: String?
    let details: String?

    enum CodingKeys: String, CodingKey {
        case reason
        case messageId = "message_id"
        case details
    }
}

nonisolated struct ReportResponse: Decodable, Sendable {
    let message: String?
}

// MARK: - Account Deletion

nonisolated struct AccountDeleteRequest: Encodable, Sendable {
    let phone: String
}

nonisolated struct AccountDeleteResponse: Decodable, Sendable {
    let deletionScheduledFor: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case deletionScheduledFor = "deletion_scheduled_for"
        case message
    }
}

nonisolated struct DeletionStatusResponse: Decodable, Sendable {
    let isPending: Bool
    let scheduledFor: String?

    enum CodingKeys: String, CodingKey {
        case isPending = "is_pending"
        case scheduledFor = "scheduled_for"
    }
}

// MARK: - Privacy Policy

nonisolated struct PrivacyDocument: Decodable, Sendable {
    let version: String
    let title: String
    let content: String
    let effectiveDate: String

    enum CodingKeys: String, CodingKey {
        case version, title, content
        case effectiveDate = "effective_date"
    }
}

nonisolated struct PrivacyAcceptRequest: Encodable, Sendable {
    let accepted: Bool
    let privacyVersion: String

    enum CodingKeys: String, CodingKey {
        case accepted
        case privacyVersion = "privacy_version"
    }
}

nonisolated struct PrivacyAcceptResponse: Decodable, Sendable {
    let message: String?
}

// MARK: - Notification Preferences

nonisolated struct NotificationPreferences: Codable, Sendable {
    var jobNotifications: Bool
    var messageNotifications: Bool
    var marketingNotifications: Bool

    enum CodingKeys: String, CodingKey {
        case jobNotifications = "job_notifications"
        case messageNotifications = "message_notifications"
        case marketingNotifications = "marketing_notifications"
    }
}

nonisolated struct NotificationPreferencesUpdate: Encodable, Sendable {
    var jobNotifications: Bool?
    var messageNotifications: Bool?
    var marketingNotifications: Bool?

    enum CodingKeys: String, CodingKey {
        case jobNotifications = "job_notifications"
        case messageNotifications = "message_notifications"
        case marketingNotifications = "marketing_notifications"
    }
}

nonisolated struct MuteConversationRequest: Encodable, Sendable {
    let mutedUntil: String?

    enum CodingKeys: String, CodingKey {
        case mutedUntil = "muted_until"
    }
}

// MARK: - Skills

nonisolated struct SkillSummary: Codable, Sendable, Equatable, Hashable {
    let name: String
    let proficiency: String
}

nonisolated struct SkillDetail: Codable, Sendable, Equatable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let category: String
}

nonisolated struct WorkerSkillItem: Codable, Sendable, Equatable, Identifiable {
    let id: Int
    let skill: SkillDetail
    let proficiency: String
}

nonisolated struct SkillsListResponse: Decodable, Sendable {
    let skills: [SkillDetail]
}

nonisolated struct WorkerSkillsResponse: Decodable, Sendable {
    let skills: [WorkerSkillItem]
}

nonisolated struct WorkerSkillEntry: Encodable, Sendable {
    let skillId: Int
    let proficiency: String

    enum CodingKeys: String, CodingKey {
        case skillId = "skill_id"
        case proficiency
    }
}

nonisolated struct UpdateWorkerSkillsRequest: Encodable, Sendable {
    let skills: [WorkerSkillEntry]
}

// MARK: - Work Experience

nonisolated struct WorkExperience: Codable, Sendable, Identifiable, Equatable, Hashable {
    let id: Int
    let title: String
    let company: String
    let description: String?
    let startDate: String
    let endDate: String?
    let isCurrent: Bool

    enum CodingKeys: String, CodingKey {
        case id, title, company, description
        case startDate = "start_date"
        case endDate = "end_date"
        case isCurrent = "is_current"
    }
}

nonisolated struct ExperienceListResponse: Decodable, Sendable {
    let experiences: [WorkExperience]
}

nonisolated struct ExperienceRequest: Encodable, Sendable {
    let title: String
    let company: String
    let description: String?
    let startDate: String
    let endDate: String?
    let isCurrent: Bool

    enum CodingKeys: String, CodingKey {
        case title, company, description
        case startDate = "start_date"
        case endDate = "end_date"
        case isCurrent = "is_current"
    }
}

nonisolated struct ExperienceResponse: Decodable, Sendable {
    let experience: WorkExperience
}

// MARK: - Availability

nonisolated struct AvailabilitySlot: Codable, Sendable, Equatable, Hashable {
    let dayOfWeek: Int
    let shiftType: String

    enum CodingKeys: String, CodingKey {
        case dayOfWeek = "day_of_week"
        case shiftType = "shift_type"
    }
}

nonisolated struct AvailabilityResponse: Decodable, Sendable {
    let slots: [AvailabilitySlot]
}

nonisolated struct UpdateAvailabilityRequest: Encodable, Sendable {
    let slots: [AvailabilitySlot]
}

// MARK: - Resume

nonisolated struct ResumeUploadURLRequest: Encodable, Sendable {
    let fileName: String
    let contentType: String
    let sizeBytes: Int

    enum CodingKeys: String, CodingKey {
        case fileName = "file_name"
        case contentType = "content_type"
        case sizeBytes = "size_bytes"
    }
}

nonisolated struct ResumeUploadURLResponse: Decodable, Sendable {
    let uploadUrl: String?
    let fileKey: String
    let resumeId: Int
    let upload: S3UploadInfo?

    enum CodingKeys: String, CodingKey {
        case uploadUrl = "upload_url"
        case fileKey = "file_key"
        case resumeId = "resume_id"
        case upload
    }
}

nonisolated struct ResumeConfirmResponse: Decodable, Sendable {
    let message: String?
}

nonisolated struct ResumeStatusResponse: Decodable, Sendable {
    let resume: ResumeInfo?
}

nonisolated struct ResumeInfo: Decodable, Sendable {
    let id: Int?
    let fileName: String?
    let fileKey: String?
    let contentType: String?
    let sizeBytes: Int?
    let uploadedAt: String?

    init(id: Int? = nil, fileName: String?, fileKey: String? = nil, contentType: String? = nil, sizeBytes: Int? = nil, uploadedAt: String?) {
        self.id = id
        self.fileName = fileName
        self.fileKey = fileKey
        self.contentType = contentType
        self.sizeBytes = sizeBytes
        self.uploadedAt = uploadedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case fileName = "file_name"
        case fileKey = "file_key"
        case contentType = "content_type"
        case sizeBytes = "size_bytes"
        case uploadedAt = "uploaded_at"
    }
}

// MARK: - Reviews

nonisolated struct ReviewRequest: Encodable, Sendable {
    let jobId: Int
    let rating: Int
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case rating, comment
    }
}

nonisolated struct ReviewResponse: Codable, Sendable, Identifiable, Equatable {
    let id: Int
    let jobId: Int
    let reviewerId: Int
    let revieweeId: Int
    let reviewerType: String
    let rating: Int
    let comment: String?
    let reviewerFirstName: String
    let reviewerLastName: String
    let reviewerPhotoUrl: String?
    let createdAt: String

    var reviewerDisplayName: String { "\(reviewerFirstName) \(reviewerLastName)" }

    enum CodingKeys: String, CodingKey {
        case id
        case jobId = "job_id"
        case reviewerId = "reviewer_id"
        case revieweeId = "reviewee_id"
        case reviewerType = "reviewer_type"
        case rating, comment
        case reviewerFirstName = "reviewer_first_name"
        case reviewerLastName = "reviewer_last_name"
        case reviewerPhotoUrl = "reviewer_photo_url"
        case createdAt = "created_at"
    }
}

nonisolated struct SubmitReviewResponse: Decodable, Sendable {
    let review: ReviewResponse
}

nonisolated struct ReviewsListResponse: Decodable, Sendable {
    let reviews: [ReviewResponse]
}

nonisolated struct PendingReviewJob: Decodable, Sendable, Identifiable, Equatable {
    let id: Int        // job_id
    let title: String
    let otherUserId: Int
    let otherUserName: String
    let otherUserPhotoUrl: String?
    let deadline: String

    enum CodingKeys: String, CodingKey {
        case id, title
        case otherUserId = "other_user_id"
        case otherUserName = "other_user_name"
        case otherUserPhotoUrl = "other_user_photo_url"
        case deadline
    }
}

nonisolated struct PendingReviewsResponse: Decodable, Sendable {
    let jobs: [PendingReviewJob]
}

nonisolated struct ReviewWorkerInfo: Decodable, Sendable, Equatable {
    let userId: Int
    let firstName: String
    let lastName: String
    let photoUrl: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case photoUrl = "photo_url"
    }
}

nonisolated struct JobCompletionReview: Decodable, Sendable, Equatable {
    let eligible: Bool
    let optional_: Bool
    let deadline: String
    let windowDays: Int
    let worker: ReviewWorkerInfo?
    let prompt: String

    static func == (lhs: JobCompletionReview, rhs: JobCompletionReview) -> Bool {
        lhs.eligible == rhs.eligible && lhs.deadline == rhs.deadline
    }

    enum CodingKeys: String, CodingKey {
        case eligible
        case optional_ = "optional"
        case deadline
        case windowDays = "window_days"
        case worker, prompt
    }
}

nonisolated struct JobCompleteResponse: Decodable, Sendable {
    let job: APIJob
    let review: JobCompletionReview?
}

// MARK: - Worker Profile Update

nonisolated struct WorkerProfileUpdateRequest: Encodable, Sendable {
    let headline: String?
    let bio: String?
}

nonisolated struct WorkerProfileUpdateResponse: Decodable, Sendable {
    let message: String?
}

// MARK: - Public Worker Profile

nonisolated struct PublicWorkerProfile: Decodable, Sendable {
    let userId: Int
    let firstName: String
    let lastName: String
    let headline: String?
    let bio: String?
    let verificationStatus: String
    let avgRating: String?
    let reviewCount: Int?
    let completedJobs: Int?
    let profileCompleteness: Int?
    let skills: [SkillSummary]?
    let experiences: [WorkExperience]?
    let availability: [AvailabilitySlot]?
    let photoUrl: String?

    var displayName: String { "\(firstName) \(lastName)" }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case headline, bio
        case verificationStatus = "verification_status"
        case avgRating = "avg_rating"
        case reviewCount = "review_count"
        case completedJobs = "completed_jobs"
        case profileCompleteness = "profile_completeness"
        case skills, experiences, availability
        case photoUrl = "photo_url"
    }
}

// MARK: - Business Profile Update

nonisolated struct BusinessProfileUpdateRequest: Encodable, Sendable {
    let companyBio: String?

    enum CodingKeys: String, CodingKey {
        case companyBio = "company_bio"
    }
}

nonisolated struct BusinessProfileUpdateResponse: Decodable, Sendable {
    let message: String?
}

// MARK: - Business Logo Upload

nonisolated struct LogoUploadURLRequest: Encodable, Sendable {
    let fileName: String
    let contentType: String
    let sizeBytes: Int?

    enum CodingKeys: String, CodingKey {
        case fileName = "file_name"
        case contentType = "content_type"
        case sizeBytes = "size_bytes"
    }
}

nonisolated struct LogoUploadURLResponse: Decodable, Sendable {
    // Supports both formats: { upload_url: "..." } or { upload: { url, fields } }
    let uploadUrl: String?
    let logoKey: String?
    let upload: S3UploadInfo?

    enum CodingKeys: String, CodingKey {
        case uploadUrl = "upload_url"
        case logoKey = "logo_key"
        case upload
    }
}

nonisolated struct LogoConfirmRequest: Encodable, Sendable {
    let fileName: String
    let contentType: String
    let sizeBytes: Int

    enum CodingKeys: String, CodingKey {
        case fileName = "file_name"
        case contentType = "content_type"
        case sizeBytes = "size_bytes"
    }
}

nonisolated struct LogoConfirmResponse: Decodable, Sendable {
    let companyLogoUrl: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case companyLogoUrl = "company_logo_url"
        case message
    }
}

// MARK: - Public Business Profile

nonisolated struct PublicBusinessProfile: Decodable, Sendable {
    let userId: Int
    let businessName: String
    let businessId: String?
    let verificationStatus: String?
    let companyBio: String?
    let companyLogoUrl: String?
    let avgRating: String?
    let reviewCount: Int?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case businessName = "business_name"
        case businessId = "business_id"
        case verificationStatus = "verification_status"
        case companyBio = "company_bio"
        case companyLogoUrl = "company_logo_url"
        case avgRating = "avg_rating"
        case reviewCount = "review_count"
    }
}

// MARK: - Data Export

nonisolated struct DataExportResponse: Decodable, Sendable {
    let exportId: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case exportId = "export_id"
        case status
    }
}

nonisolated struct DataExportStatusResponse: Decodable, Sendable {
    let export: DataExportInfo

    struct DataExportInfo: Decodable, Sendable {
        let id: String
        let status: String
        let downloadUrl: String?
        let downloadExpiresAt: String?
        let createdAt: String

        enum CodingKeys: String, CodingKey {
            case id, status
            case downloadUrl = "download_url"
            case downloadExpiresAt = "download_expires_at"
            case createdAt = "created_at"
        }
    }
}

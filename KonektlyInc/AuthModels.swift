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

    /// Cache-busted URL for 256px avatar display
    var displayURL: URL? {
        guard let urlString = url256, !urlString.isEmpty else { return nil }
        if let v = version {
            return URL(string: "\(urlString)?v=\(v)")
        }
        return URL(string: urlString)
    }

    /// Cache-busted URL for 64px thumbnail
    var thumbnailURL: URL? {
        guard let urlString = url64, !urlString.isEmpty else { return nil }
        if let v = version {
            return URL(string: "\(urlString)?v=\(v)")
        }
        return URL(string: urlString)
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

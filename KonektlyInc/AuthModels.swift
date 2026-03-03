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
    case otpExpired = "OTP_EXPIRED"
    case otpInvalid = "OTP_INVALID"
    case otpRateLimit = "OTP_RATE_LIMIT"
    case firebaseError = "FIREBASE_ERROR"
    case tokenExpired = "TOKEN_EXPIRED"
    case unauthorized = "UNAUTHORIZED"
    case emailAlreadyVerified = "EMAIL_ALREADY_VERIFIED"
    case emailTokenInvalid = "EMAIL_TOKEN_INVALID"
    case emailTokenExpired = "EMAIL_TOKEN_EXPIRED"
    // Profile
    case profileAlreadyExists = "PROFILE_ALREADY_EXISTS"
    case profileNotFound = "PROFILE_NOT_FOUND"
    case validationError = "VALIDATION_ERROR"
    // Generic
    case rateLimited = "RATE_LIMITED"
    case serverError = "SERVER_ERROR"
    case unknown = "UNKNOWN"

    var userFacingMessage: String {
        switch self {
        case .invalidPhone: return "Please enter a valid phone number."
        case .otpExpired: return "Your verification code has expired. Please request a new one."
        case .otpInvalid: return "Incorrect code. Please try again."
        case .otpRateLimit: return "Too many attempts. Please wait before requesting a new code."
        case .firebaseError: return "Phone verification failed. Please try again."
        case .tokenExpired: return "Your session has expired. Please sign in again."
        case .unauthorized: return "You are not authorised to perform this action."
        case .emailAlreadyVerified: return "This email address is already verified."
        case .emailTokenInvalid: return "The verification link is invalid."
        case .emailTokenExpired: return "The verification link has expired. Please request a new one."
        case .profileAlreadyExists: return "A profile already exists for this account."
        case .profileNotFound: return "Profile not found."
        case .validationError: return "Please check the information you entered."
        case .rateLimited: return "You're doing that too fast. Please wait a moment."
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

// Primary: Firebase id_token flow
nonisolated struct VerifyOTPFirebaseRequest: Encodable, Sendable {
    let phone: String
    let id_token: String
}

// Dev fallback: plain code
nonisolated struct VerifyOTPDevRequest: Encodable, Sendable {
    let phone: String
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

// MARK: - Me / Current User

nonisolated struct AuthUser: Decodable, Sendable, Equatable {
    let id: Int
    let username: String?
    let phone: String?
    let email: String?
    let isEmailVerified: Bool
    let isActiveProfile: Bool
    let workerProfile: AnyCodable?
    let businessProfile: AnyCodable?
    let accessTier: String?
    let phoneVerifiedAt: String?
    let emailVerifiedAt: String?

    // Convenience computed properties for the rest of the app
    var emailVerified: Bool { isEmailVerified }
    var hasWorkerProfile: Bool { workerProfile != nil }
    var hasBusinessProfile: Bool { businessProfile != nil }

    enum CodingKeys: String, CodingKey {
        case id, username, phone, email
        case isEmailVerified = "is_email_verified"
        case isActiveProfile = "is_active_profile"
        case workerProfile = "worker_profile"
        case businessProfile = "business_profile"
        case accessTier = "access_tier"
        case phoneVerifiedAt = "phone_verified_at"
        case emailVerifiedAt = "email_verified_at"
    }

    static func == (lhs: AuthUser, rhs: AuthUser) -> Bool {
        lhs.id == rhs.id
            && lhs.phone == rhs.phone
            && lhs.email == rhs.email
            && lhs.isEmailVerified == rhs.isEmailVerified
            && lhs.isActiveProfile == rhs.isActiveProfile
            && lhs.accessTier == rhs.accessTier
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

// MARK: - Profiles

nonisolated struct WorkerProfileCreateRequest: Encodable, Sendable {
    let firstName: String
    let lastName: String
    let bio: String
    let skills: [String]
    let hourlyRate: Double
    let availableFrom: String?  // ISO-8601 date string

    enum CodingKeys: String, CodingKey {
        case bio, skills
        case firstName = "first_name"
        case lastName = "last_name"
        case hourlyRate = "hourly_rate"
        case availableFrom = "available_from"
    }
}

nonisolated struct BusinessProfileCreateRequest: Encodable, Sendable {
    let businessName: String
    let industry: String
    let description: String
    let website: String?

    enum CodingKeys: String, CodingKey {
        case industry, description, website
        case businessName = "business_name"
    }
}

nonisolated struct ProfileCreateResponse: Decodable, Sendable {
    let id: String?
    let message: String?
}

// MARK: - Verification Status

nonisolated struct ProfileStatus: Decodable, Sendable {
    let workerStatus: AnyCodable?
    let businessStatus: AnyCodable?
    let isActiveProfile: Bool
    let accessTier: String

    // Convenience for the rest of the app
    var hasWorkerProfile: Bool { workerStatus != nil }
    var hasBusinessProfile: Bool { businessStatus != nil }

    enum CodingKeys: String, CodingKey {
        case workerStatus = "worker_status"
        case businessStatus = "business_status"
        case isActiveProfile = "is_active_profile"
        case accessTier = "access_tier"
    }
}

nonisolated struct AccessTier: Decodable, Sendable {
    let accessTier: String

    enum CodingKeys: String, CodingKey {
        case accessTier = "access_tier"
    }
}

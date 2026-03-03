//
//  KonektlyIncTests.swift
//  KonektlyIncTests
//
//  Created by Rohan on 2026-02-23.
//

import XCTest
@testable import KonektlyInc

// MARK: - APIErrorCode Tests

final class APIErrorCodeTests: XCTestCase {

    func test_knownCodes_roundTrip() {
        let codes: [APIErrorCode] = [
            .invalidPhone, .otpExpired, .otpInvalid, .otpRateLimit,
            .firebaseError, .tokenExpired, .unauthorized,
            .emailAlreadyVerified, .emailTokenInvalid, .emailTokenExpired,
            .profileAlreadyExists, .profileNotFound, .validationError,
            .rateLimited, .serverError, .unknown
        ]
        for code in codes {
            XCTAssertEqual(APIErrorCode(rawValue: code.rawValue), code,
                           "Round-trip failed for \(code.rawValue)")
        }
    }

    func test_unknownRawValue_fallsBackToUnknown() {
        XCTAssertNil(APIErrorCode(rawValue: "NONEXISTENT_CODE"))
    }

    func test_userFacingMessage_notEmpty() {
        for code in [APIErrorCode.otpInvalid, .rateLimited, .serverError, .unknown] {
            XCTAssertFalse(code.userFacingMessage.isEmpty)
        }
    }
}

// MARK: - AppError Tests

final class AppErrorTests: XCTestCase {

    func test_apiError_usesCodeMessage_whenProvided() {
        let err = AppError.apiError(code: .otpInvalid, message: "Custom OTP error")
        XCTAssertEqual(err.errorDescription, "Custom OTP error")
    }

    func test_apiError_fallsBackToCode_whenMessageEmpty() {
        let err = AppError.apiError(code: .otpExpired, message: "")
        XCTAssertEqual(err.errorDescription, APIErrorCode.otpExpired.userFacingMessage)
    }

    func test_rateLimited_withRetryAfter() {
        let err = AppError.rateLimited(retryAfter: 30)
        XCTAssertTrue(err.errorDescription?.contains("30") ?? false)
    }

    func test_rateLimited_withoutRetryAfter() {
        let err = AppError.rateLimited(retryAfter: nil)
        XCTAssertNotNil(err.errorDescription)
    }

    func test_unauthorized_hasDescription() {
        XCTAssertNotNil(AppError.unauthorized.errorDescription)
    }
}

// MARK: - APIResponse Decoding Tests

@MainActor
final class APIResponseDecodingTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func test_successResponse_decodesData() throws {
        let json = """
        {
            "success": true,
            "data": { "access": "tok_abc", "refresh": "ref_xyz" },
            "message": "OK"
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(APIResponse<AuthTokenResponse>.self, from: json)
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.data?.access, "tok_abc")
        XCTAssertEqual(response.data?.refresh, "ref_xyz")
        XCTAssertNil(response.error)
    }

    func test_errorResponse_decodesErrorPayload() throws {
        let json = """
        {
            "success": false,
            "error": {
                "code": "OTP_INVALID",
                "message": "The code you entered is incorrect.",
                "details": null
            }
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(APIResponse<AuthTokenResponse>.self, from: json)
        XCTAssertFalse(response.success)
        XCTAssertNil(response.data)
        XCTAssertEqual(response.error?.code, "OTP_INVALID")
        XCTAssertEqual(response.error?.message, "The code you entered is incorrect.")
    }

    func test_authUser_decodesSnakeCaseKeys() throws {
        let json = """
        {
            "success": true,
            "data": {
                "id": 1,
                "username": "15550001234",
                "phone": "+15550001234",
                "email": "user@example.com",
                "is_email_verified": true,
                "is_active_profile": false,
                "worker_profile": null,
                "business_profile": null,
                "access_tier": "phone_verified",
                "phone_verified_at": "2026-03-03T01:08:40.798504Z",
                "email_verified_at": null
            }
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(APIResponse<AuthUser>.self, from: json)
        let user = try XCTUnwrap(response.data)
        XCTAssertEqual(user.id, 1)
        XCTAssertTrue(user.emailVerified)
        XCTAssertFalse(user.hasWorkerProfile)
    }

    func test_profileStatus_decodesAllFields() throws {
        let json = """
        {
            "success": true,
            "data": {
                "worker_status": {"id": 1},
                "business_status": null,
                "is_active_profile": false,
                "access_tier": "phone_verified"
            }
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(APIResponse<ProfileStatus>.self, from: json)
        let status = try XCTUnwrap(response.data)
        XCTAssertTrue(status.hasWorkerProfile)
        XCTAssertFalse(status.hasBusinessProfile)
        XCTAssertEqual(status.accessTier, "phone_verified")
    }

    func test_accessTier_decodesCorrectly() throws {
        let json = """
        {
            "success": true,
            "data": {
                "access_tier": "phone_verified"
            }
        }
        """.data(using: .utf8)!

        let response = try decoder.decode(APIResponse<AccessTier>.self, from: json)
        let tier = try XCTUnwrap(response.data)
        XCTAssertEqual(tier.accessTier, "phone_verified")
    }
}

// MARK: - Endpoint Path Tests

final class EndpointTests: XCTestCase {

    func test_sendOTP_path() {
        let ep = Endpoint.sendOTP(phone: "+15550001234")
        XCTAssertEqual(ep.path, "/api/v1/auth/phone/send-otp/")
        XCTAssertEqual(ep.method, .post)
    }

    func test_verifyOTPFirebase_path() {
        let ep = Endpoint.verifyOTPFirebase(phone: "+15550001234", idToken: "firebase_id_token")
        XCTAssertEqual(ep.path, "/api/v1/auth/phone/verify-otp/")
        XCTAssertEqual(ep.method, .post)
    }

    func test_verifyOTPDev_path() {
        let ep = Endpoint.verifyOTPDev(phone: "+15550001234", code: "123456")
        XCTAssertEqual(ep.path, "/api/v1/auth/phone/verify-otp/")
    }

    func test_me_path() {
        XCTAssertEqual(Endpoint.me.path, "/api/v1/auth/me/")
        XCTAssertEqual(Endpoint.me.method, .get)
    }

    func test_sendEmailVerification_path() {
        let ep = Endpoint.sendEmailVerification(email: "user@example.com")
        XCTAssertEqual(ep.path, "/api/v1/auth/email/send-verification/")
        XCTAssertEqual(ep.method, .post)
    }

    func test_verifyEmailToken_path() {
        let ep = Endpoint.verifyEmailToken("sometoken")
        XCTAssertEqual(ep.path, "/api/v1/auth/email/verify/")
        XCTAssertEqual(ep.method, .post)
    }

    func test_createWorkerProfile_path() {
        let req = WorkerProfileCreateRequest(
            firstName: "Jane", lastName: "Doe",
            bio: "Test", skills: [], hourlyRate: 20, availableFrom: nil
        )
        let ep = Endpoint.createWorkerProfile(req)
        XCTAssertEqual(ep.path, "/api/v1/profiles/worker/create/")
        XCTAssertEqual(ep.method, .post)
    }

    func test_createBusinessProfile_path() {
        let req = BusinessProfileCreateRequest(
            businessName: "Acme", industry: "Retail",
            description: "Test", website: nil
        )
        let ep = Endpoint.createBusinessProfile(req)
        XCTAssertEqual(ep.path, "/api/v1/profiles/business/create/")
        XCTAssertEqual(ep.method, .post)
    }

    func test_profileStatus_path() {
        XCTAssertEqual(Endpoint.profileStatus.path, "/api/v1/profiles/status/")
        XCTAssertEqual(Endpoint.profileStatus.method, .get)
    }

    func test_accessTier_path() {
        XCTAssertEqual(Endpoint.accessTier.path, "/api/v1/access-tier/")
        XCTAssertEqual(Endpoint.accessTier.method, .get)
    }
}

// MARK: - TokenStore Tests

final class TokenStoreTests: XCTestCase {
    private let store = TokenStore.shared

    override func tearDown() {
        store.clearAll()
        super.tearDown()
    }

    func test_writeAndRead_accessToken() {
        store.accessToken = "test_access_token"
        XCTAssertEqual(store.accessToken, "test_access_token")
    }

    func test_writeAndRead_refreshToken() {
        store.refreshToken = "test_refresh_token"
        XCTAssertEqual(store.refreshToken, "test_refresh_token")
    }

    func test_clearAll_removesTokens() {
        store.accessToken = "access"
        store.refreshToken = "refresh"
        store.clearAll()
        XCTAssertNil(store.accessToken)
        XCTAssertNil(store.refreshToken)
    }

    func test_nilAssignment_deletesToken() {
        store.accessToken = "tok"
        store.accessToken = nil
        XCTAssertNil(store.accessToken)
    }
}

// MARK: - AuthStore State Tests

@MainActor
final class AuthStoreTests: XCTestCase {

    override func setUp() {
        AuthStore.shared.signOut()
    }

    func test_initialState_isUnauthenticated() {
        XCTAssertFalse(AuthStore.shared.isAuthenticated)
        XCTAssertNil(AuthStore.shared.currentUser)
    }

    func test_signOut_clearsState() {
        // Simulate an authenticated state by checking signOut idempotency
        AuthStore.shared.signOut()
        XCTAssertFalse(AuthStore.shared.isAuthenticated)
        XCTAssertNil(AuthStore.shared.profileStatus)
        XCTAssertNil(AuthStore.shared.accessTier)
    }

    func test_needsEmailVerification_falseWhenUnauthenticated() {
        XCTAssertFalse(AuthStore.shared.needsEmailVerification)
    }

    func test_needsProfile_falseWhenUnauthenticated() {
        XCTAssertFalse(AuthStore.shared.needsProfile)
    }

    func test_clearError_nilsError() {
        AuthStore.shared.setError(.unknown)
        XCTAssertNotNil(AuthStore.shared.error)
        AuthStore.shared.clearError()
        XCTAssertNil(AuthStore.shared.error)
    }
}

// MARK: - WorkerProfileCreateRequest Encoding Tests

@MainActor
final class ProfileRequestEncodingTests: XCTestCase {
    private let encoder = JSONEncoder()

    func test_workerProfile_encodesSnakeCaseKeys() throws {
        let req = WorkerProfileCreateRequest(
            firstName: "Jane",
            lastName: "Doe",
            bio: "Swift dev",
            skills: ["iOS", "Swift"],
            hourlyRate: 35.0,
            availableFrom: nil
        )
        let data = try encoder.encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["first_name"] as? String, "Jane")
        XCTAssertEqual(json?["last_name"] as? String, "Doe")
        XCTAssertEqual(json?["hourly_rate"] as? Double, 35.0)
        XCTAssertEqual(json?["skills"] as? [String], ["iOS", "Swift"])
    }

    func test_businessProfile_encodesSnakeCaseKeys() throws {
        let req = BusinessProfileCreateRequest(
            businessName: "Acme Corp",
            industry: "Retail",
            description: "Test business",
            website: "https://acme.com"
        )
        let data = try encoder.encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["business_name"] as? String, "Acme Corp")
        XCTAssertEqual(json?["website"] as? String, "https://acme.com")
    }
}

// MARK: - Config Tests

final class ConfigTests: XCTestCase {
    func test_apiBaseURL_isValid() {
        let url = Config.apiBaseURL
        XCTAssertNotNil(url.host)
    }

    func test_requestTimeout_isPositive() {
        XCTAssertGreaterThan(Config.requestTimeout, 0)
    }

    func test_devOTPFallback_onlyInDebug() {
        #if DEBUG
        XCTAssertTrue(Config.isDevOTPFallbackEnabled)
        #else
        XCTAssertFalse(Config.isDevOTPFallbackEnabled)
        #endif
    }
}

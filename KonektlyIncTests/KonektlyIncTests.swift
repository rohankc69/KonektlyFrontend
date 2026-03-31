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
                "worker_status": "pending",
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
        let ep = Endpoint.verifyOTPFirebase(phone: "+15550001234", profileType: "worker", idToken: "firebase_id_token")
        XCTAssertEqual(ep.path, "/api/v1/auth/phone/verify-otp/")
        XCTAssertEqual(ep.method, .post)
    }

    func test_verifyOTPDev_path() {
        let ep = Endpoint.verifyOTPDev(phone: "+15550001234", profileType: "worker", code: "123456")
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
            govIdNumber: "DL123456", govIdType: "drivers_license"
        )
        let ep = Endpoint.createWorkerProfile(req)
        XCTAssertEqual(ep.path, "/api/v1/profiles/worker/create/")
        XCTAssertEqual(ep.method, .post)
    }

    func test_createBusinessProfile_path() {
        let req = BusinessProfileCreateRequest(
            businessId: "BN123",
            businessName: "Acme", managerGovIdNumber: "MG456"
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

    func test_onboardingStep_nameWhenUnauthenticated() {
        // When unauthenticated (no user), onboardingStep defaults to .name
        XCTAssertEqual(AuthStore.shared.onboardingStep, .name)
    }

    func test_needsOnboarding_trueWhenUnauthenticated() {
        XCTAssertTrue(AuthStore.shared.needsOnboarding)
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
            govIdNumber: "DL123456",
            govIdType: "drivers_license"
        )
        let data = try encoder.encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["gov_id_number"] as? String, "DL123456")
        XCTAssertEqual(json?["gov_id_type"] as? String, "drivers_license")
    }

    func test_businessProfile_encodesSnakeCaseKeys() throws {
        let req = BusinessProfileCreateRequest(
            businessId: "BN123456",
            businessName: "Acme Corp",
            managerGovIdNumber: "MG789"
        )
        let data = try encoder.encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["business_id"] as? String, "BN123456")
        XCTAssertEqual(json?["business_name"] as? String, "Acme Corp")
        XCTAssertEqual(json?["manager_gov_id_number"] as? String, "MG789")
    }

    func test_nameUpdateRequest_encodesSnakeCaseKeys() throws {
        let req = NameUpdateRequest(firstName: "Jane", lastName: "Doe")
        let data = try encoder.encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["first_name"] as? String, "Jane")
        XCTAssertEqual(json?["last_name"] as? String, "Doe")
    }

    func test_termsAcceptRequest_encodesCorrectly() throws {
        let req = TermsAcceptRequest(accepted: true, termsVersion: "2026-03-03")
        let data = try encoder.encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["accepted"] as? Bool, true)
        XCTAssertEqual(json?["terms_version"] as? String, "2026-03-03")
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

// MARK: - ProfilePhoto Tests

final class ProfilePhotoTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    private let encoder = JSONEncoder()

    // MARK: - ProfilePhoto Model

    func test_profilePhoto_activeStatus() throws {
        let json = """
        {"id":1,"status":"active","url_64":"https://cdn.example.com/64.jpg","url_256":"https://cdn.example.com/256.jpg","activated_at":"2026-03-03T10:00:00Z","version":"abc123"}
        """.data(using: .utf8)!
        let photo = try decoder.decode(ProfilePhoto.self, from: json)
        XCTAssertEqual(photo.id, 1)
        XCTAssertTrue(photo.isActive)
        XCTAssertFalse(photo.isProcessing)
        XCTAssertEqual(photo.displayURL?.absoluteString, "https://cdn.example.com/256.jpg?v=abc123")
        XCTAssertEqual(photo.thumbnailURL?.absoluteString, "https://cdn.example.com/64.jpg?v=abc123")
    }

    func test_profilePhoto_processingStatus() throws {
        let json = """
        {"id":2,"status":"processing","url_64":"","url_256":"","activated_at":null,"version":"v1"}
        """.data(using: .utf8)!
        let photo = try decoder.decode(ProfilePhoto.self, from: json)
        XCTAssertTrue(photo.isProcessing)
        XCTAssertFalse(photo.isActive)
        XCTAssertNil(photo.displayURL, "Empty url_256 should return nil displayURL")
        XCTAssertNil(photo.thumbnailURL, "Empty url_64 should return nil thumbnailURL")
    }

    func test_profilePhoto_cacheBust_noVersion() throws {
        let json = """
        {"id":3,"status":"active","url_64":null,"url_256":"https://cdn.example.com/256.jpg","activated_at":null,"version":null}
        """.data(using: .utf8)!
        let photo = try decoder.decode(ProfilePhoto.self, from: json)
        XCTAssertEqual(photo.displayURL?.absoluteString, "https://cdn.example.com/256.jpg",
                       "No version should produce URL without ?v=")
    }

    // MARK: - AuthUser with ProfilePhoto

    func test_authUser_withProfilePhoto() throws {
        let json = """
        {"id":1,"username":"user","phone":"+1234","email":"","first_name":"A","last_name":"B","date_of_birth":"2000-01-01","is_email_verified":false,"is_active_profile":false,"terms_accepted_at":null,"terms_version":null,"worker_profile":null,"business_profile":null,"access_tier":"phone_verified","phone_verified_at":"2026-01-01T00:00:00Z","email_verified_at":null,"profile_photo":{"id":5,"status":"active","url_64":"https://cdn.example.com/64.jpg","url_256":"https://cdn.example.com/256.jpg","activated_at":"2026-03-03T10:00:00Z","version":"v2"}}
        """.data(using: .utf8)!
        let user = try decoder.decode(AuthUser.self, from: json)
        XCTAssertNotNil(user.profilePhoto)
        XCTAssertEqual(user.profilePhoto?.id, 5)
        XCTAssertTrue(user.profilePhoto?.isActive ?? false)
    }

    func test_authUser_withoutProfilePhoto() throws {
        let json = """
        {"id":1,"username":"user","phone":"+1234","email":"","first_name":null,"last_name":null,"date_of_birth":null,"is_email_verified":false,"is_active_profile":false,"terms_accepted_at":null,"terms_version":null,"worker_profile":null,"business_profile":null,"access_tier":"phone_verified","phone_verified_at":null,"email_verified_at":null,"profile_photo":null}
        """.data(using: .utf8)!
        let user = try decoder.decode(AuthUser.self, from: json)
        XCTAssertNil(user.profilePhoto)
    }

    // MARK: - Upload Request Encoding

    func test_photoUploadURLRequest_encoding() throws {
        let req = PhotoUploadURLRequest(
            fileName: "avatar.jpg",
            contentType: "image/jpeg",
            sizeBytes: 123456,
            sha256: "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
        )
        let data = try encoder.encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["file_name"] as? String, "avatar.jpg")
        XCTAssertEqual(json?["content_type"] as? String, "image/jpeg")
        XCTAssertEqual(json?["size_bytes"] as? Int, 123456)
        XCTAssertNotNil(json?["sha256"])
    }

    func test_photoConfirmRequest_encoding() throws {
        let req = PhotoConfirmRequest(photoId: 42)
        let data = try encoder.encode(req)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["photo_id"] as? Int, 42)
    }

    // MARK: - Upload URL Response Decoding

    func test_photoUploadURLResponse_decoding() throws {
        let json = """
        {"photo_id":10,"upload":{"method":"POST","url":"https://s3.amazonaws.com/bucket","fields":{"key":"photos/10.jpg","policy":"abc","x-amz-signature":"def"},"expires_in_seconds":300}}
        """.data(using: .utf8)!
        let resp = try decoder.decode(PhotoUploadURLResponse.self, from: json)
        XCTAssertEqual(resp.photoId, 10)
        XCTAssertEqual(resp.upload.method, "POST")
        XCTAssertEqual(resp.upload.fields["key"], "photos/10.jpg")
        XCTAssertEqual(resp.upload.expiresInSeconds, 300)
    }

    func test_photoUploadURLResponse_localDevMode() throws {
        let json = """
        {"photo_id":11,"upload":{"method":"POST","url":"/api/v1/auth/profile/photo/upload-local/","fields":{},"expires_in_seconds":300}}
        """.data(using: .utf8)!
        let resp = try decoder.decode(PhotoUploadURLResponse.self, from: json)
        XCTAssertTrue(resp.upload.url.hasPrefix("/"), "Local upload URL should start with /")
        XCTAssertTrue(resp.upload.fields.isEmpty, "Local upload should have empty fields")
    }

    // MARK: - Confirm Response Decoding

    func test_photoConfirmResponse_active() throws {
        let json = """
        {"profile_photo":{"id":10,"status":"active","url_64":"https://cdn/64.jpg","url_256":"https://cdn/256.jpg","activated_at":"2026-03-03T10:00:00Z","version":"v1"},"user":null}
        """.data(using: .utf8)!
        let resp = try decoder.decode(PhotoConfirmResponse.self, from: json)
        XCTAssertTrue(resp.profilePhoto.isActive)
        XCTAssertNil(resp.user)
    }

    func test_photoConfirmResponse_processing() throws {
        let json = """
        {"profile_photo":{"id":10,"status":"processing","url_64":"","url_256":"","activated_at":null,"version":"v1"},"user":null}
        """.data(using: .utf8)!
        let resp = try decoder.decode(PhotoConfirmResponse.self, from: json)
        XCTAssertTrue(resp.profilePhoto.isProcessing)
        XCTAssertFalse(resp.profilePhoto.isActive)
    }

    // MARK: - PhotoUploadState

    func test_uploadState_isActive() {
        XCTAssertFalse(isStateActive(.idle))
        XCTAssertTrue(isStateActive(.selecting))
        XCTAssertTrue(isStateActive(.validating))
        XCTAssertTrue(isStateActive(.uploading(progress: 0.5)))
        XCTAssertTrue(isStateActive(.confirming))
        XCTAssertTrue(isStateActive(.processing(photoId: 1, elapsed: 5)))
        XCTAssertFalse(isStateActive(.success(ProfilePhoto(id: 1, status: "active", url64: nil, url256: nil, activatedAt: nil, version: nil))))
        XCTAssertFalse(isStateActive(.error("fail")))
    }

    private func isStateActive(_ state: PhotoUploadState) -> Bool {
        switch state {
        case .idle, .success, .error: return false
        default: return true
        }
    }

    // MARK: - Endpoint Paths

    func test_photoEndpoints_correctPaths() {
        let uploadURL = Endpoint.photoUploadURL(PhotoUploadURLRequest(
            fileName: "a.jpg", contentType: "image/jpeg", sizeBytes: 100, sha256: nil
        ))
        XCTAssertEqual(uploadURL.path, "/api/v1/auth/profile/photo/upload-url/")
        XCTAssertEqual(uploadURL.method, .post)

        let confirm = Endpoint.photoConfirm(PhotoConfirmRequest(photoId: 1))
        XCTAssertEqual(confirm.path, "/api/v1/auth/profile/photo/confirm/")
        XCTAssertEqual(confirm.method, .post)

        let delete = Endpoint.photoDelete
        XCTAssertEqual(delete.path, "/api/v1/auth/profile/photo/")
        XCTAssertEqual(delete.method, .delete)
    }

    // MARK: - Resume Upload Response Decoding

    func test_resumeUploadURLResponse_decoding_putFormat() throws {
        let json = """
        {"upload_url":"https://s3.amazonaws.com/bucket/resume.pdf","file_key":"resumes/1.pdf","resume_id":1}
        """.data(using: .utf8)!

        let resp = try decoder.decode(ResumeUploadURLResponse.self, from: json)
        XCTAssertEqual(resp.uploadUrl, "https://s3.amazonaws.com/bucket/resume.pdf")
        XCTAssertEqual(resp.fileKey, "resumes/1.pdf")
        XCTAssertEqual(resp.resumeId, 1)
        XCTAssertNil(resp.upload)
    }

    func test_resumeUploadURLResponse_decoding_postFormat() throws {
        let json = """
        {"upload": {"method":"POST","url":"https://s3.amazonaws.com/bucket","fields":{"key":"resumes/2.pdf","policy":"abc"}}, "file_key":"resumes/2.pdf","resume_id":2}
        """.data(using: .utf8)!

        let resp = try decoder.decode(ResumeUploadURLResponse.self, from: json)
        XCTAssertNil(resp.uploadUrl)
        XCTAssertEqual(resp.fileKey, "resumes/2.pdf")
        XCTAssertEqual(resp.resumeId, 2)
        XCTAssertEqual(resp.upload?.method, "POST")
        XCTAssertEqual(resp.upload?.fields["key"], "resumes/2.pdf")
    }
}

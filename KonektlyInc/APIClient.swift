//
//  APIClient.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import Foundation

// MARK: - Token Store (Keychain-backed)

/// Pure value-access class - no actor isolation, safe to call from any context.
nonisolated final class TokenStore: @unchecked Sendable {
    static let shared = TokenStore()
    private init() {}

    private let accessKey = "konektly.access_token"
    private let refreshKey = "konektly.refresh_token"

    var accessToken: String? {
        get { read(key: accessKey) }
        set { newValue == nil ? delete(key: accessKey) : write(key: accessKey, value: newValue!) }
    }

    var refreshToken: String? {
        get { read(key: refreshKey) }
        set { newValue == nil ? delete(key: refreshKey) : write(key: refreshKey, value: newValue!) }
    }

    func clearAll() {
        delete(key: accessKey)
        delete(key: refreshKey)
    }

    // MARK: Keychain helpers

    private func write(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - API Client

actor APIClient {
    static let shared = APIClient()
    private init() {}

    // Timeout values stored as nonisolated constants so they are accessible
    // from stored-property initializer closures without a MainActor hop.
    private nonisolated let requestTimeout: TimeInterval = Config.requestTimeout
    private nonisolated let resourceTimeout: TimeInterval = Config.resourceTimeout

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = resourceTimeout
        return URLSession(configuration: config)
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    // Prevent concurrent token refreshes
    private var isRefreshing = false
    private var refreshContinuations: [CheckedContinuation<String, Error>] = []

    // MARK: - Public Request Methods

    /// Authenticated request - injects Bearer token and handles 401 refresh automatically.
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        authenticated: Bool = true
    ) async throws -> T {
        let urlRequest = try buildRequest(endpoint: endpoint, authenticated: authenticated)
        return try await execute(urlRequest, endpoint: endpoint, authenticated: authenticated, retryCount: 0)
    }

    /// Unauthenticated convenience wrapper.
    func publicRequest<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        try await request(endpoint, authenticated: false)
    }

    /// Authenticated request that also returns the HTTP status code.
    /// Used by confirm endpoint to distinguish 200 (active) from 202 (processing).
    func requestWithStatus<T: Decodable>(
        _ endpoint: Endpoint,
        authenticated: Bool = true
    ) async throws -> (T, Int) {
        let urlRequest = try buildRequest(endpoint: endpoint, authenticated: authenticated)
        return try await executeWithStatus(urlRequest, endpoint: endpoint, authenticated: authenticated, retryCount: 0)
    }

    /// Upload file to S3 using presigned POST fields.
    /// Returns the HTTP status code (expect 201 or 204).
    func uploadToS3(
        url: String,
        fields: [String: String],
        fileData: Data,
        contentType: String,
        fileName: String
    ) async throws -> Int {
        guard let uploadURL = URL(string: url) else { throw AppError.unknown }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        var body = Data()

        // Add all presigned fields first
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // Append file as the last field (required by S3)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        print("[API] [POST S3] \(url) (\(fileData.count) bytes)")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.unknown
        }

        print("[API] S3 upload status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 201 || httpResponse.statusCode == 204 else {
            throw AppError.apiError(code: .uploadFailed, message: "S3 upload returned \(httpResponse.statusCode)")
        }

        return httpResponse.statusCode
    }

    /// Upload file to backend local storage (dev mode).
    /// The backend returns upload.url as a relative path like /api/v1/auth/profile/photo/upload-local/.
    /// Requires Bearer auth header and photo_id in the form body.
    func uploadLocal(
        path: String,
        photoId: Int,
        fileData: Data,
        contentType: String,
        fileName: String
    ) async throws -> Int {
        let url = Config.apiBaseURL.appendingPathComponent(path)
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        if let token = TokenStore.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()

        // photo_id field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(photoId)\r\n".data(using: .utf8)!)

        // file field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        print("[API] [POST LOCAL] \(url.absoluteString) (\(fileData.count) bytes)")

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.unknown
        }

        print("[API] Local upload status: \(httpResponse.statusCode)")

        guard (200...204).contains(httpResponse.statusCode) else {
            throw AppError.apiError(code: .uploadFailed, message: "Local upload returned \(httpResponse.statusCode)")
        }

        return httpResponse.statusCode
    }

    // MARK: - Build URLRequest

    private func buildRequest(endpoint: Endpoint, authenticated: Bool) throws -> URLRequest {
        var components = URLComponents(
            url: Config.apiBaseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: true
        )
        if let queryItems = endpoint.queryItems {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw AppError.unknown
        }
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = endpoint.body {
            request.httpBody = try encoder.encode(body)
        }

        // TokenStore is @unchecked Sendable - safe to read from any isolation context.
        if authenticated, let token = TokenStore.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // MARK: - Execute with retry

    private func execute<T: Decodable>(
        _ request: URLRequest,
        endpoint: Endpoint,
        authenticated: Bool,
        retryCount: Int
    ) async throws -> T {
        let urlString = request.url?.absoluteString ?? "?"
        print("[API] [\(endpoint.method.rawValue)] \(urlString)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            print("[API] Network error for \(urlString): \(error)")
            throw AppError.network(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.unknown
        }

        print("[API] HTTP \(httpResponse.statusCode) <- \(urlString)")
        if let body = String(data: data, encoding: .utf8) {
            let truncated = body.count > 1000 ? String(body.prefix(1000)) + "...<truncated>" : body
            print("[API] Response body: \(truncated)")
        }

        // Rate limit (429)
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) }
            throw AppError.rateLimited(retryAfter: retryAfter)
        }

        // Conflict (409) — could be a job-specific code or legacy profile conflict
        if httpResponse.statusCode == 409 {
            if let envelope = try? decoder.decode(APIResponse<EmptyResponse>.self, from: data),
               let errorPayload = envelope.error {
                let code = APIErrorCode(rawValue: errorPayload.code) ?? .unknown
                switch code {
                case .jobNotOpen, .alreadyApplied, .applicationAlreadyProcessed:
                    throw AppError.apiError(code: code, message: errorPayload.message)
                default:
                    throw AppError.conflict(message: errorPayload.message)
                }
            }
            let msg = parseErrorMessage(data: data) ?? "This profile is already verified and cannot be changed."
            throw AppError.conflict(message: msg)
        }

        // Service unavailable (503) - OTP service down
        if httpResponse.statusCode == 503 {
            let msg = parseErrorMessage(data: data) ?? "Service is temporarily unavailable. Please try again later."
            throw AppError.serviceUnavailable(message: msg)
        }

        // Unauthorised - try token refresh once
        if httpResponse.statusCode == 401 && authenticated && retryCount == 0 {
            let newToken = try await refreshAccessToken()
            var retryRequest = request
            retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            return try await execute(retryRequest, endpoint: endpoint, authenticated: authenticated, retryCount: 1)
        }

        return try decodeResponse(data: data, statusCode: httpResponse.statusCode)
    }

    /// Same as execute but also returns the HTTP status code.
    private func executeWithStatus<T: Decodable>(
        _ request: URLRequest,
        endpoint: Endpoint,
        authenticated: Bool,
        retryCount: Int
    ) async throws -> (T, Int) {
        let urlString = request.url?.absoluteString ?? "?"
        print("[API] [\(endpoint.method.rawValue)] \(urlString)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            print("[API] Network error for \(urlString): \(error)")
            throw AppError.network(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.unknown
        }

        let statusCode = httpResponse.statusCode
        print("[API] HTTP \(statusCode) <- \(urlString)")
        if let body = String(data: data, encoding: .utf8) {
            let truncated = body.count > 1000 ? String(body.prefix(1000)) + "...<truncated>" : body
            print("[API] Response body: \(truncated)")
        }

        if statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Double($0) }
            throw AppError.rateLimited(retryAfter: retryAfter)
        }
        if statusCode == 409 {
            if let envelope = try? decoder.decode(APIResponse<EmptyResponse>.self, from: data),
               let errorPayload = envelope.error {
                let code = APIErrorCode(rawValue: errorPayload.code) ?? .unknown
                switch code {
                case .jobNotOpen, .alreadyApplied, .applicationAlreadyProcessed:
                    throw AppError.apiError(code: code, message: errorPayload.message)
                default:
                    throw AppError.conflict(message: errorPayload.message)
                }
            }
            let msg = parseErrorMessage(data: data) ?? "This profile is already verified and cannot be changed."
            throw AppError.conflict(message: msg)
        }
        if statusCode == 503 {
            let msg = parseErrorMessage(data: data) ?? "Service is temporarily unavailable. Please try again later."
            throw AppError.serviceUnavailable(message: msg)
        }
        if statusCode == 401 && authenticated && retryCount == 0 {
            let newToken = try await refreshAccessToken()
            var retryRequest = request
            retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            return try await executeWithStatus(retryRequest, endpoint: endpoint, authenticated: authenticated, retryCount: 1)
        }

        let decoded: T = try decodeResponse(data: data, statusCode: statusCode)
        return (decoded, statusCode)
    }

    // MARK: - Token Refresh

    private func refreshAccessToken() async throws -> String {
        // TokenStore is @unchecked Sendable - safe to read from actor context.
        guard let refreshToken = TokenStore.shared.refreshToken else {
            throw AppError.unauthorized
        }

        if isRefreshing {
            // Enqueue and wait for the in-flight refresh to complete.
            return try await withCheckedThrowingContinuation { continuation in
                refreshContinuations.append(continuation)
            }
        }

        isRefreshing = true

        struct RefreshRequest: Encodable, Sendable { let refresh: String }
        struct RefreshResponse: Decodable, Sendable { let access: String }

        let endpoint = Endpoint(
            path: "/api/v1/auth/token/refresh/",
            method: .post,
            body: AnyEncodable(RefreshRequest(refresh: refreshToken))
        )

        do {
            let response: RefreshResponse = try await publicRequest(endpoint)

            // Persist new access token - TokenStore is @unchecked Sendable.
            TokenStore.shared.accessToken = response.access

            // Unblock all waiting callers - resume() is synchronous, no await needed.
            let continuations = refreshContinuations
            refreshContinuations.removeAll()
            isRefreshing = false
            for cont in continuations { cont.resume(returning: response.access) }

            return response.access
        } catch {
            // Clear tokens and reject all waiters on refresh failure.
            TokenStore.shared.clearAll()
            let continuations = refreshContinuations
            refreshContinuations.removeAll()
            isRefreshing = false
            for cont in continuations { cont.resume(throwing: AppError.unauthorized) }
            throw AppError.unauthorized
        }
    }

    // MARK: - Decode Response

    private func parseErrorMessage(data: Data) -> String? {
        if let envelope = try? decoder.decode(APIResponse<EmptyResponse>.self, from: data) {
            return envelope.error?.message
        }
        return nil
    }

    private struct EmptyResponse: Decodable, Sendable {}

    private func decodeResponse<T: Decodable>(data: Data, statusCode: Int) throws -> T {
        do {
            let envelope = try decoder.decode(APIResponse<T>.self, from: data)
            if envelope.success, let result = envelope.data {
                return result
            }
            // Map error payload to AppError
            if let errorPayload = envelope.error {
                let code = APIErrorCode(rawValue: errorPayload.code) ?? .unknown
                throw AppError.apiError(code: code, message: errorPayload.message)
            }
            throw AppError.unknown
        } catch let appError as AppError {
            throw appError
        } catch {
            print("[API] Decode error: \(error)")
            if let raw = String(data: data, encoding: .utf8) {
                print("[API] Raw data that failed to decode: \(raw)")
            }
            throw AppError.decoding(underlying: error)
        }
    }
}

// MARK: - Endpoint

nonisolated struct Endpoint: Sendable {
    let path: String
    let method: HTTPMethod
    let body: AnyEncodable?
    let queryItems: [URLQueryItem]?

    init(path: String, method: HTTPMethod = .get, body: AnyEncodable? = nil, queryItems: [URLQueryItem]? = nil) {
        self.path = path
        self.method = method
        self.body = body
        self.queryItems = queryItems
    }
}

nonisolated enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - AnyEncodable (type-erasure for request bodies)

nonisolated struct AnyEncodable: Encodable, @unchecked Sendable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        _encode = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

// MARK: - Endpoint Namespace

extension Endpoint {
    // Auth
    static func sendOTP(phone: String) -> Endpoint {
        Endpoint(path: "/api/v1/auth/phone/send-otp/", method: .post,
                 body: AnyEncodable(SendOTPRequest(phone: phone)))
    }

    static func verifyOTPFirebase(phone: String, profileType: String, idToken: String) -> Endpoint {
        Endpoint(path: "/api/v1/auth/phone/verify-otp/", method: .post,
                 body: AnyEncodable(VerifyOTPFirebaseRequest(phone: phone, profile_type: profileType, id_token: idToken)))
    }

    static func verifyOTPDev(phone: String, profileType: String, code: String) -> Endpoint {
        Endpoint(path: "/api/v1/auth/phone/verify-otp/", method: .post,
                 body: AnyEncodable(VerifyOTPDevRequest(phone: phone, profile_type: profileType, code: code)))
    }

    static let me = Endpoint(path: "/api/v1/auth/me/", method: .get)

    static func sendEmailVerification(email: String) -> Endpoint {
        Endpoint(path: "/api/v1/auth/email/send-verification/", method: .post,
                 body: AnyEncodable(SendEmailVerificationRequest(email: email)))
    }

    static func verifyEmailToken(_ token: String) -> Endpoint {
        Endpoint(path: "/api/v1/auth/email/verify/", method: .post,
                 body: AnyEncodable(VerifyEmailTokenRequest(token: token)))
    }

    static func createWorkerProfile(_ req: WorkerProfileCreateRequest) -> Endpoint {
        Endpoint(path: "/api/v1/profiles/worker/create/", method: .post,
                 body: AnyEncodable(req))
    }

    static func createBusinessProfile(_ req: BusinessProfileCreateRequest) -> Endpoint {
        Endpoint(path: "/api/v1/profiles/business/create/", method: .post,
                 body: AnyEncodable(req))
    }

    // Name update (step 4)
    static func updateName(_ req: NameUpdateRequest) -> Endpoint {
        Endpoint(path: "/api/v1/auth/profile/name/", method: .patch,
                 body: AnyEncodable(req))
    }

    // DOB update (step 5)
    static func updateDOB(_ req: DOBUpdateRequest) -> Endpoint {
        Endpoint(path: "/api/v1/auth/profile/dob/", method: .patch,
                 body: AnyEncodable(req))
    }

    // Terms accept (step 6)
    static func acceptTerms(_ req: TermsAcceptRequest) -> Endpoint {
        Endpoint(path: "/api/v1/auth/terms/accept/", method: .post,
                 body: AnyEncodable(req))
    }

    /// GET /api/v1/legal/terms/ — fetch live terms document (no auth required)
    /// Always call this before showing TermsAcceptView.
    /// The version returned MUST be forwarded to POST /auth/terms/accept/.
    static let currentTerms = Endpoint(path: "/api/v1/legal/terms/", method: .get)

    static let profileStatus = Endpoint(path: "/api/v1/profiles/status/", method: .get)
    static let accessTier = Endpoint(path: "/api/v1/access-tier/", method: .get)

    // Photo
    static func photoUploadURL(_ req: PhotoUploadURLRequest) -> Endpoint {
        Endpoint(path: "/api/v1/auth/profile/photo/upload-url/", method: .post,
                 body: AnyEncodable(req))
    }

    static func photoConfirm(_ req: PhotoConfirmRequest) -> Endpoint {
        Endpoint(path: "/api/v1/auth/profile/photo/confirm/", method: .post,
                 body: AnyEncodable(req))
    }

    static let photoDelete = Endpoint(path: "/api/v1/auth/profile/photo/", method: .delete)

    // MARK: - Jobs Endpoints

    /// POST /api/v1/jobs/ — Business: post a new open job
    static func postJob(_ req: PostJobRequest) -> Endpoint {
        Endpoint(path: "/api/v1/jobs/", method: .post, body: AnyEncodable(req))
    }

    /// GET /api/v1/jobs/nearby/?lat=&lng=&radius=
    static func nearbyJobs(lat: Double?, lng: Double?, postalCode: String? = nil, radius: Int? = nil) -> Endpoint {
        var items: [URLQueryItem] = []
        if let lat = lat { items.append(URLQueryItem(name: "lat", value: "\(lat)")) }
        if let lng = lng { items.append(URLQueryItem(name: "lng", value: "\(lng)")) }
        if let pc = postalCode { items.append(URLQueryItem(name: "postal_code", value: pc)) }
        if let r = radius { items.append(URLQueryItem(name: "radius", value: "\(r)")) }
        return Endpoint(path: "/api/v1/jobs/nearby/", method: .get, queryItems: items.isEmpty ? nil : items)
    }

    /// GET /api/v1/jobs/{jobId}/workers/?radius=
    static func workersNearJob(jobId: Int, radius: Int? = nil) -> Endpoint {
        var items: [URLQueryItem] = []
        if let r = radius { items.append(URLQueryItem(name: "radius", value: "\(r)")) }
        return Endpoint(path: "/api/v1/jobs/\(jobId)/workers/", method: .get, queryItems: items.isEmpty ? nil : items)
    }

    /// POST /api/v1/jobs/{jobId}/apply/
    static func applyForJob(jobId: Int, coverNote: String?) -> Endpoint {
        Endpoint(path: "/api/v1/jobs/\(jobId)/apply/", method: .post,
                 body: AnyEncodable(ApplyForJobRequest(coverNote: coverNote)))
    }

    /// GET /api/v1/jobs/{jobId}/applications/
    static func jobApplications(jobId: Int) -> Endpoint {
        Endpoint(path: "/api/v1/jobs/\(jobId)/applications/", method: .get)
    }

    /// GET /api/v1/my/applications/?status=&lat=&lng= — worker's own applications
    /// Pass lat+lng to receive distance_km and distance_m on each embedded job.
    static func myApplications(status: String? = nil, lat: Double? = nil, lng: Double? = nil) -> Endpoint {
        var items: [URLQueryItem] = []
        if let status { items.append(URLQueryItem(name: "status", value: status)) }
        if let lat    { items.append(URLQueryItem(name: "lat",    value: String(format: "%.6f", lat))) }
        if let lng    { items.append(URLQueryItem(name: "lng",    value: String(format: "%.6f", lng))) }
        return Endpoint(
            path: "/api/v1/my/applications/",
            method: .get,
            queryItems: items.isEmpty ? nil : items
        )
    }

    /// POST /api/v1/jobs/{jobId}/hire/{applicationId}/
    static func hireWorker(jobId: Int, applicationId: Int) -> Endpoint {
        Endpoint(path: "/api/v1/jobs/\(jobId)/hire/\(applicationId)/", method: .post)
    }
}

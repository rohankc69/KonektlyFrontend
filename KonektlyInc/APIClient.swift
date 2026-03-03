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

        // Conflict (409) - profile already verified / non-editable
        if httpResponse.statusCode == 409 {
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

    static let profileStatus = Endpoint(path: "/api/v1/profiles/status/", method: .get)
    static let accessTier = Endpoint(path: "/api/v1/access-tier/", method: .get)
}

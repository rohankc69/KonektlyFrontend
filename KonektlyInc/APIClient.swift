//
//  APIClient.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import Foundation
import Security

// MARK: - Token Store (Keychain-backed)

/// Pure value-access class - no actor isolation, safe to call from any context.
nonisolated final class TokenStore: @unchecked Sendable {
    static let shared = TokenStore()
    private init() {}

    private let accessKey = "konektly.access_token"
    private let refreshKey = "konektly.refresh_token"

    /// Keep the access token in-memory by default (faster, avoids unnecessary Keychain IO).
    /// It will still be re-hydrated from refresh token when needed.
    private var inMemoryAccessToken: String?

    var accessToken: String? {
        get { inMemoryAccessToken }
        set { inMemoryAccessToken = newValue }
    }

    /// Refresh token must be persisted securely.
    var refreshToken: String? {
        get { read(key: refreshKey) }
        set { newValue == nil ? delete(key: refreshKey) : write(key: refreshKey, value: newValue!) }
    }

    func clearAll() {
        inMemoryAccessToken = nil
        delete(key: accessKey) // backwards-compat: clear if older builds persisted access
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

    /// Treat task/URLSession cancellations separately so UI layers can ignore
    /// expected refresh cancellations instead of showing a network error.
    private nonisolated func isCancellation(_ error: any Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        // Accept both ISO8601 variants from backend:
        // - 2026-03-30T18:00:00Z
        // - 2026-03-30T18:00:00.123456Z
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)

            let isoParsers: [ISO8601DateFormatter] = {
                let withFractional = ISO8601DateFormatter()
                withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let plain = ISO8601DateFormatter()
                plain.formatOptions = [.withInternetDateTime]
                return [withFractional, plain]
            }()
            for parser in isoParsers {
                if let date = parser.date(from: raw) { return date }
            }

            // Handle extended fractional precision with explicit timezone offset,
            // e.g. 2026-03-30T05:13:05.297673+00:00
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = TimeZone(secondsFromGMT: 0)
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSXXXXX",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSXXXXX",
                "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
                "yyyy-MM-dd'T'HH:mm:ssXXXXX"
            ]
            for format in formats {
                df.dateFormat = format
                if let date = df.date(from: raw) { return date }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(raw)"
            )
        }
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
        fileName: String,
        orderedFields: [(key: String, value: String)]? = nil
    ) async throws -> Int {
        guard let uploadURL = URL(string: url) else { throw AppError.unknown }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        var body = Data()

        // Add all presigned fields first — use ordered list if available (S3 cares about order)
        let fieldPairs: [(key: String, value: String)] = orderedFields ?? fields.map { ($0.key, $0.value) }
        for (key, value) in fieldPairs {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // Append file as the last field (required by S3).
        // Use the Content-Type from the signed policy fields when present — mismatching
        // the value the backend signed causes an immediate S3 SignatureDoesNotMatch 403.
        let signedContentType = fieldPairs.first(where: {
            $0.key.lowercased() == "content-type"
        })?.value ?? contentType
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(signedContentType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        print("[API] [POST S3] \(url) (\(fileData.count) bytes)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            print("[API] [POST S3] transport error for \(uploadURL.absoluteString): \(error)")
            throw AppError.network(underlying: error)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.unknown
        }

        print("[API] S3 upload status: \(httpResponse.statusCode)")

        // S3 presigned POST returns 200 (default), 201 (if success_action_status=201),
        // or 204 (if success_action_status=204).
        guard (200...204).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[API] S3 upload failed — status \(httpResponse.statusCode), body: \(responseBody.prefix(500))")
            throw AppError.apiError(code: .uploadFailed, message: uploadFailureMessage(statusCode: httpResponse.statusCode))
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

        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            print("[API] [POST LOCAL] transport error for \(url.absoluteString): \(error)")
            throw AppError.network(underlying: error)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.unknown
        }

        print("[API] Local upload status: \(httpResponse.statusCode)")

        guard (200...204).contains(httpResponse.statusCode) else {
            throw AppError.apiError(code: .uploadFailed, message: uploadFailureMessage(statusCode: httpResponse.statusCode))
        }

        return httpResponse.statusCode
    }

    /// Upload raw file data to S3 using a presigned PUT URL (no multipart).
    /// Used by resume upload.
    func uploadToS3Put(url: String, fileData: Data, contentType: String) async throws -> Int {
        // Resolve relative URLs from dev backend by prepending apiBaseURL
        let resolvedURL: URL
        let isLocal: Bool
        if url.hasPrefix("http://") || url.hasPrefix("https://") {
            guard let parsed = URL(string: url) else { throw AppError.unknown }
            resolvedURL = parsed
            isLocal = false
        } else {
            let base = Config.apiBaseURL.absoluteString.hasSuffix("/")
                ? String(Config.apiBaseURL.absoluteString.dropLast())
                : Config.apiBaseURL.absoluteString
            let path = url.hasPrefix("/") ? url : "/" + url
            guard let parsed = URL(string: base + path) else { throw AppError.unknown }
            resolvedURL = parsed
            isLocal = true
        }

        var request = URLRequest(url: resolvedURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = fileData
        request.timeoutInterval = 120

        // Add auth header for local dev uploads (not S3)
        if isLocal, let token = TokenStore.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        print("[API] [PUT S3] \(resolvedURL.absoluteString) (\(fileData.count) bytes)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            print("[API] [PUT S3] transport error for \(resolvedURL.absoluteString): \(error)")
            throw AppError.network(underlying: error)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.unknown
        }

        print("[API] S3 PUT upload status: \(httpResponse.statusCode)")

        guard (200...204).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "(no body)"
            print("[API] S3 PUT failed — status \(httpResponse.statusCode), body: \(responseBody.prefix(500))")
            throw AppError.apiError(code: .uploadFailed, message: uploadFailureMessage(statusCode: httpResponse.statusCode))
        }
        return httpResponse.statusCode
    }

    private nonisolated func uploadFailureMessage(statusCode: Int) -> String {
        switch statusCode {
        case 400:
            return "Upload rejected (400). Please check file type and size."
        case 409:
            return "Upload conflict (409). Please refresh and try again."
        case 429:
            return "Too many upload attempts (429). Please wait and retry."
        default:
            return "Upload failed (HTTP \(statusCode)). Please try again."
        }
    }

    // MARK: - Build URLRequest

    private func buildRequest(endpoint: Endpoint, authenticated: Bool) throws -> URLRequest {
        // Use URL(string:relativeTo:) to preserve trailing slashes on endpoint paths.
        // appendingPathComponent(_:) silently strips trailing slashes, which causes
        // Django to issue a 301 redirect for POST/PATCH requests, and URLSession
        // follows those redirects with GET — resulting in 405 errors in production.
        let base = Config.apiBaseURL.absoluteString.hasSuffix("/")
            ? String(Config.apiBaseURL.absoluteString.dropLast())
            : Config.apiBaseURL.absoluteString
        let resolvedURL = URL(string: base + endpoint.path) ?? Config.apiBaseURL
        var components = URLComponents(
            url: resolvedURL,
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

        if let key = endpoint.idempotencyKey {
            request.setValue(key, forHTTPHeaderField: "Idempotency-Key")
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
            if isCancellation(error) {
                throw CancellationError()
            }
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
                case .jobNotOpen, .alreadyApplied, .applicationAlreadyProcessed,
                     .alreadyReviewed, .reviewWindowExpired, .jobNotCompleted,
                     .notAParticipant, .noCompletedShift, .maxExperiencesReached:
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
            do {
                let newToken = try await refreshAccessToken()
                var retryRequest = request
                retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                return try await execute(retryRequest, endpoint: endpoint, authenticated: authenticated, retryCount: 1)
            } catch {
                // Refresh failed: tokens already cleared by refreshAccessToken().
                throw AppError.unauthorized
            }
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
            if isCancellation(error) {
                throw CancellationError()
            }
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
                case .jobNotOpen, .alreadyApplied, .applicationAlreadyProcessed,
                     .alreadyReviewed, .reviewWindowExpired, .jobNotCompleted,
                     .notAParticipant, .noCompletedShift, .maxExperiencesReached:
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
            do {
                let newToken = try await refreshAccessToken()
                var retryRequest = request
                retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                return try await executeWithStatus(retryRequest, endpoint: endpoint, authenticated: authenticated, retryCount: 1)
            } catch {
                throw AppError.unauthorized
            }
        }

        let decoded: T = try decodeResponse(data: data, statusCode: statusCode)
        return (decoded, statusCode)
    }

    // MARK: - Token Refresh

    private func refreshAccessToken() async throws -> String {
        guard let refreshToken = TokenStore.shared.refreshToken else {
            throw AppError.unauthorized
        }

        if isRefreshing {
            return try await withCheckedThrowingContinuation { continuation in
                refreshContinuations.append(continuation)
            }
        }

        isRefreshing = true

        // Backend allows aliases: refresh_token, refreshToken, token.
        // We send the canonical "refresh".
        struct RefreshRequest: Encodable, Sendable { let refresh: String }

        struct RotatedTokensResponse: Decodable, Sendable {
            struct TokenPair: Decodable, Sendable {
                let access: String
                let refresh: String
            }
            let tokens: TokenPair
        }

        let endpoint = Endpoint(
            path: "/api/v1/auth/token/refresh/",
            method: .post,
            body: AnyEncodable(RefreshRequest(refresh: refreshToken))
        )

        do {
            let response: RotatedTokensResponse = try await publicRequest(endpoint)

            // Rotation: persist new refresh and update in-memory access.
            TokenStore.shared.accessToken = response.tokens.access
            TokenStore.shared.refreshToken = response.tokens.refresh

            let continuations = refreshContinuations
            refreshContinuations.removeAll()
            isRefreshing = false
            for cont in continuations { cont.resume(returning: response.tokens.access) }

            return response.tokens.access
        } catch {
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
            if envelope.success {
                // Happy path: data field present
                if let result = envelope.data { return result }
                // Void endpoints return {"success":true,"message":"..."} with no data field.
                // If T is VoidAPIResponse we can construct a value with no data.
                if let void = VoidAPIResponse() as? T { return void }
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

    // MARK: - Bootstrap / Session Management

    /// Best-effort token bootstrap.
    /// Loads a fresh access token if we only have a refresh token (rotating refresh tokens supported).
    /// No UX changes: failures are swallowed and will surface naturally on protected calls.
    func bootstrapTokensIfNeeded() async {
        // If we already have an access token in memory, nothing to do.
        if TokenStore.shared.accessToken != nil { return }
        // If we don't have refresh, nothing to do.
        guard TokenStore.shared.refreshToken != nil else { return }
        do {
            _ = try await refreshAccessToken()
        } catch {
            print("[API] bootstrapTokensIfNeeded: refresh failed: \(error)")
        }
    }

    /// Backend logout: blacklists the refresh token (idempotent). Always clears local tokens.
    func logout() async {
        guard let refreshToken = TokenStore.shared.refreshToken else {
            TokenStore.shared.clearAll()
            return
        }

        struct LogoutRequest: Encodable, Sendable { let refresh: String }
        let endpoint = Endpoint(
            path: "/api/v1/auth/logout/",
            method: .post,
            body: AnyEncodable(LogoutRequest(refresh: refreshToken))
        )

        do {
            let _: VoidAPIResponse = try await publicRequest(endpoint)
        } catch {
            // Idempotent endpoint: ignore errors and still clear local tokens.
            print("[API] logout call failed (ignored): \(error)")
        }

        TokenStore.shared.clearAll()
    }
}

// MARK: - API Client Extensions for Subscriptions

extension APIClient {
    
    /// POST /subscriptions/apple/validate/
    func validateAppleTransaction(jwsTransaction: String) async throws -> SubscriptionStatus {
        let body = AppleValidateRequest(jwsTransaction: jwsTransaction)
        return try await request(.validateAppleTransaction(body))
    }
    
    /// GET /subscriptions/me/
    func fetchSubscriptionStatus() async throws -> SubscriptionStatus {
        return try await request(.subscriptionStatus)
    }
}

// MARK: - Endpoint

nonisolated struct Endpoint: Sendable {
    let path: String
    let method: HTTPMethod
    let body: AnyEncodable?
    let queryItems: [URLQueryItem]?
    let idempotencyKey: String?

    init(path: String, method: HTTPMethod = .get, body: AnyEncodable? = nil, queryItems: [URLQueryItem]? = nil, idempotencyKey: String? = nil) {
        self.path = path
        self.method = method
        self.body = body
        self.queryItems = queryItems
        self.idempotencyKey = idempotencyKey
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

/// Empty JSON body `{}` for endpoints that require a body but no fields.
nonisolated struct EmptyBody: Encodable, Sendable {}

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

    /// GET /api/v1/jobs/{jobId}/ — Fetch a single job by ID
    static func jobDetail(jobId: Int) -> Endpoint {
        Endpoint(path: "/api/v1/jobs/\(jobId)/", method: .get)
    }

    /// POST /api/v1/jobs/ — Business: post a new open job
    static func postJob(_ req: PostJobRequest) -> Endpoint {
        Endpoint(path: "/api/v1/jobs/", method: .post, body: AnyEncodable(req))
    }

    /// GET /api/v1/jobs/mine/ — Business: list all jobs posted by this business
    /// Returns the same JobObject shape as nearby jobs.
    /// Optional ?status= filter: "open" | "filled" | "cancelled" | "completed"
    static func myPostedJobs(status: String? = nil) -> Endpoint {
        var items: [URLQueryItem] = []
        if let status { items.append(URLQueryItem(name: "status", value: status)) }
        return Endpoint(
            path: "/api/v1/jobs/mine/",
            method: .get,
            queryItems: items.isEmpty ? nil : items
        )
    }

    /// GET /api/v1/jobs/nearby/?lat=&lng=&radius=&filter=
    static func nearbyJobs(lat: Double?, lng: Double?, postalCode: String? = nil,
                            radius: Int? = nil, filter: String? = nil) -> Endpoint {
        var items: [URLQueryItem] = []
        if let lat = lat { items.append(URLQueryItem(name: "lat",         value: "\(lat)")) }
        if let lng = lng { items.append(URLQueryItem(name: "lng",         value: "\(lng)")) }
        if let pc  = postalCode { items.append(URLQueryItem(name: "postal_code", value: pc)) }
        if let r   = radius { items.append(URLQueryItem(name: "radius",   value: "\(r)")) }
        if let f   = filter { items.append(URLQueryItem(name: "filter",   value: f)) }
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

    /// POST /api/v1/jobs/{jobId}/complete/ — Business: mark a filled job as completed
    /// No request body. Job must be in "filled" status.
    static func completeJob(jobId: Int) -> Endpoint {
        Endpoint(path: "/api/v1/jobs/\(jobId)/complete/", method: .post)
    }
    
    // MARK: - Subscriptions Endpoints
    
    /// POST /api/v1/subscriptions/apple/validate/
    static func validateAppleTransaction(_ req: AppleValidateRequest) -> Endpoint {
        Endpoint(path: "/api/v1/subscriptions/apple/validate/", method: .post,
                 body: AnyEncodable(req))
    }
    
    /// GET /api/v1/subscriptions/me/
    static let subscriptionStatus = Endpoint(path: "/api/v1/subscriptions/me/", method: .get)

    // MARK: - Messaging Endpoints

    /// POST /api/v1/messages/conversations/start/ — Business starts pre-hire chat with an applicant
    static func startConversation(_ req: StartConversationRequest) -> Endpoint {
        Endpoint(path: "/api/v1/messages/conversations/start/", method: .post, body: AnyEncodable(req))
    }

    /// GET /api/v1/messages/conversations/
    static let conversations = Endpoint(path: "/api/v1/messages/conversations/", method: .get)

    /// GET /api/v1/messages/conversations/<id>/
    static func conversationMessages(conversationId: UUID, before: UUID? = nil) -> Endpoint {
        var items: [URLQueryItem] = []
        if let before { items.append(URLQueryItem(name: "before", value: before.uuidString.lowercased())) }
        return Endpoint(
            path: "/api/v1/messages/conversations/\(conversationId.uuidString.lowercased())/",
            method: .get,
            queryItems: items.isEmpty ? nil : items
        )
    }

    /// GET /api/v1/messages/unread-count/
    static let unreadCount = Endpoint(path: "/api/v1/messages/unread-count/", method: .get)

    /// POST /api/v1/messages/devices/register/
    static func registerDevice(_ req: DeviceRegisterRequest) -> Endpoint {
        Endpoint(path: "/api/v1/messages/devices/register/", method: .post, body: AnyEncodable(req))
    }

    /// POST /api/v1/messages/devices/unregister/
    static func unregisterDevice(_ req: DeviceUnregisterRequest) -> Endpoint {
        Endpoint(path: "/api/v1/messages/devices/unregister/", method: .post, body: AnyEncodable(req))
    }

    // MARK: - Block / Report Endpoints

    /// POST /api/v1/users/<id>/block/
    static func blockUser(userId: Int) -> Endpoint {
        Endpoint(path: "/api/v1/users/\(userId)/block/", method: .post)
    }

    /// DELETE /api/v1/users/<id>/block/
    static func unblockUser(userId: Int) -> Endpoint {
        Endpoint(path: "/api/v1/users/\(userId)/block/", method: .delete)
    }

    /// GET /api/v1/users/blocked/
    static let blockedUsers = Endpoint(path: "/api/v1/users/blocked/", method: .get)

    /// POST /api/v1/messages/conversations/<uuid>/report/
    static func reportConversation(conversationId: UUID, _ req: ReportRequest) -> Endpoint {
        Endpoint(path: "/api/v1/messages/conversations/\(conversationId.uuidString.lowercased())/report/", method: .post, body: AnyEncodable(req))
    }

    // MARK: - Account Deletion

    /// POST /api/v1/auth/account/delete/
    static func deleteAccount(_ req: AccountDeleteRequest) -> Endpoint {
        Endpoint(path: "/api/v1/auth/account/delete/", method: .post, body: AnyEncodable(req))
    }

    /// GET /api/v1/auth/account/deletion-status/
    static let deletionStatus = Endpoint(path: "/api/v1/auth/account/deletion-status/", method: .get)

    // MARK: - Privacy Policy

    /// GET /api/v1/legal/privacy/
    static let currentPrivacy = Endpoint(path: "/api/v1/legal/privacy/", method: .get)

    /// POST /api/v1/auth/privacy/accept/
    static func acceptPrivacy(_ req: PrivacyAcceptRequest) -> Endpoint {
        Endpoint(path: "/api/v1/auth/privacy/accept/", method: .post, body: AnyEncodable(req))
    }

    // MARK: - Notification Preferences

    /// Job / message / legacy marketing toggles (`messaging.NotificationPreference`).
    /// GET/PATCH /api/v1/messages/notification-preferences/
    static let messagingNotificationPreferences = Endpoint(path: "/api/v1/messages/notification-preferences/", method: .get)

    static func updateMessagingNotificationPreferences(_ req: NotificationPreferencesUpdate) -> Endpoint {
        Endpoint(path: "/api/v1/messages/notification-preferences/", method: .patch, body: AnyEncodable(req))
    }

    /// Push campaign prefs (`notifications.UserNotificationPreference`).
    /// GET/PATCH /api/v1/notifications/preferences/
    static let pushNotificationPreferences = Endpoint(path: "/api/v1/notifications/preferences/", method: .get)

    static func updatePushNotificationPreferences(_ req: PushNotificationPreferencesUpdate) -> Endpoint {
        Endpoint(path: "/api/v1/notifications/preferences/", method: .patch, body: AnyEncodable(req))
    }

    /// GET /api/v1/notifications/history/?page=&page_size=
    static func notificationHistory(page: Int, pageSize: Int) -> Endpoint {
        Endpoint(
            path: "/api/v1/notifications/history/?page=\(page)&page_size=\(pageSize)",
            method: .get
        )
    }

    /// POST /api/v1/messages/conversations/<uuid>/mute/
    static func muteConversation(conversationId: UUID, mutedUntil: String? = nil) -> Endpoint {
        Endpoint(path: "/api/v1/messages/conversations/\(conversationId.uuidString.lowercased())/mute/", method: .post,
                 body: AnyEncodable(MuteConversationRequest(mutedUntil: mutedUntil)))
    }

    /// DELETE /api/v1/messages/conversations/<uuid>/mute/
    static func unmuteConversation(conversationId: UUID) -> Endpoint {
        Endpoint(path: "/api/v1/messages/conversations/\(conversationId.uuidString.lowercased())/mute/", method: .delete)
    }

    // MARK: - Data Export

    /// POST /api/v1/auth/account/export/
    static let requestDataExport = Endpoint(path: "/api/v1/auth/account/export/", method: .post)

    /// GET /api/v1/auth/account/export/status/
    static let dataExportStatus = Endpoint(path: "/api/v1/auth/account/export/status/", method: .get)

    // MARK: - Worker Profile Update

    /// PATCH /api/v1/profiles/worker/update/
    static func updateWorkerProfile(_ req: WorkerProfileUpdateRequest) -> Endpoint {
        Endpoint(path: "/api/v1/profiles/worker/update/", method: .patch, body: AnyEncodable(req))
    }

    // MARK: - Skills Endpoints

    /// GET /api/v1/skills/ — all active skills, optional search/category filters
    static func allSkills(search: String? = nil, category: String? = nil) -> Endpoint {
        var items: [URLQueryItem] = []
        if let search, !search.isEmpty { items.append(URLQueryItem(name: "search", value: search)) }
        if let category { items.append(URLQueryItem(name: "category", value: category)) }
        return Endpoint(path: "/api/v1/skills/", method: .get, queryItems: items.isEmpty ? nil : items)
    }

    /// GET /api/v1/profiles/worker/skills/ — my current skills
    static let mySkills = Endpoint(path: "/api/v1/profiles/worker/skills/", method: .get)

    /// PUT /api/v1/profiles/worker/skills/ — replace all skills (atomic)
    static func updateSkills(_ req: UpdateWorkerSkillsRequest, idempotencyKey: String) -> Endpoint {
        Endpoint(path: "/api/v1/profiles/worker/skills/", method: .put, body: AnyEncodable(req), idempotencyKey: idempotencyKey)
    }

    // MARK: - Experience Endpoints

    /// GET /api/v1/profiles/worker/experience/
    static let myExperiences = Endpoint(path: "/api/v1/profiles/worker/experience/", method: .get)

    /// POST /api/v1/profiles/worker/experience/
    static func addExperience(_ req: ExperienceRequest, idempotencyKey: String) -> Endpoint {
        Endpoint(path: "/api/v1/profiles/worker/experience/", method: .post, body: AnyEncodable(req), idempotencyKey: idempotencyKey)
    }

    /// PATCH /api/v1/profiles/worker/experience/<id>/
    static func updateExperience(id: Int, _ req: ExperienceRequest) -> Endpoint {
        Endpoint(path: "/api/v1/profiles/worker/experience/\(id)/", method: .patch, body: AnyEncodable(req))
    }

    /// DELETE /api/v1/profiles/worker/experience/<id>/
    static func deleteExperience(id: Int) -> Endpoint {
        Endpoint(path: "/api/v1/profiles/worker/experience/\(id)/", method: .delete)
    }

    // MARK: - Availability Endpoints

    /// GET /api/v1/profiles/worker/availability/
    static let myAvailability = Endpoint(path: "/api/v1/profiles/worker/availability/", method: .get)

    /// PUT /api/v1/profiles/worker/availability/
    static func updateAvailability(_ req: UpdateAvailabilityRequest, idempotencyKey: String) -> Endpoint {
        Endpoint(path: "/api/v1/profiles/worker/availability/", method: .put, body: AnyEncodable(req), idempotencyKey: idempotencyKey)
    }

    // MARK: - Resume Endpoints

    /// POST /api/v1/profiles/worker/resume/upload-url/
    static func resumeUploadURL(_ req: ResumeUploadURLRequest, idempotencyKey: String) -> Endpoint {
        Endpoint(path: "/api/v1/profiles/worker/resume/upload-url/", method: .post, body: AnyEncodable(req), idempotencyKey: idempotencyKey)
    }

    /// POST /api/v1/profiles/worker/resume/confirm/ — empty body per backend spec
    static let resumeConfirm = Endpoint(path: "/api/v1/profiles/worker/resume/confirm/", method: .post, body: AnyEncodable(EmptyBody()))

    /// GET /api/v1/profiles/worker/resume/ — check current resume status
    static let resumeStatus = Endpoint(path: "/api/v1/profiles/worker/resume/", method: .get)

    /// DELETE /api/v1/profiles/worker/resume/
    static let resumeDelete = Endpoint(path: "/api/v1/profiles/worker/resume/", method: .delete)

    // MARK: - Reviews Endpoints

    /// POST /api/v1/reviews/
    static func submitReview(_ req: ReviewRequest, idempotencyKey: String) -> Endpoint {
        Endpoint(path: "/api/v1/reviews/", method: .post, body: AnyEncodable(req), idempotencyKey: idempotencyKey)
    }

    /// GET /api/v1/reviews/pending/
    static let pendingReviews = Endpoint(path: "/api/v1/reviews/pending/", method: .get)

    /// GET /api/v1/reviews/user/<user_id>/
    static func userReviews(userId: Int) -> Endpoint {
        Endpoint(path: "/api/v1/reviews/user/\(userId)/", method: .get)
    }

    /// GET /api/v1/reviews/mine/
    static let myReviews = Endpoint(path: "/api/v1/reviews/mine/", method: .get)

    // MARK: - Public Worker Profile

    /// GET /api/v1/profiles/worker/<user_id>/public/
    static func publicWorkerProfile(userId: Int) -> Endpoint {
        Endpoint(path: "/api/v1/profiles/worker/\(userId)/public/", method: .get)
    }

    // MARK: - Business Profile Endpoints

    /// PATCH /api/v1/profiles/business/update/
    static func updateBusinessProfile(_ req: BusinessProfileUpdateRequest) -> Endpoint {
        Endpoint(path: "/api/v1/profiles/business/update/", method: .patch, body: AnyEncodable(req))
    }

    /// POST /api/v1/profiles/business/logo/upload-url/
    static func businessLogoUploadURL(_ req: LogoUploadURLRequest) -> Endpoint {
        Endpoint(path: "/api/v1/profiles/business/logo/upload-url/", method: .post, body: AnyEncodable(req))
    }

    /// POST /api/v1/profiles/business/logo/confirm/ — empty body per backend spec
    static let businessLogoConfirm = Endpoint(
        path: "/api/v1/profiles/business/logo/confirm/", method: .post, body: AnyEncodable(EmptyBody())
    )

    /// DELETE /api/v1/profiles/business/logo/
    static let deleteBusinessLogo = Endpoint(path: "/api/v1/profiles/business/logo/", method: .delete)

    /// GET /api/v1/profiles/business/<user_id>/public/
    static func publicBusinessProfile(userId: Int) -> Endpoint {
        Endpoint(path: "/api/v1/profiles/business/\(userId)/public/", method: .get)
    }

    // MARK: - Support Endpoints

    /// GET /api/v1/support/tickets/
    static let supportTickets = Endpoint(path: "/api/v1/support/tickets/", method: .get)

    /// POST /api/v1/support/tickets/
    static func createTicket(_ req: CreateTicketRequest) -> Endpoint {
        Endpoint(path: "/api/v1/support/tickets/", method: .post, body: AnyEncodable(req))
    }

    /// GET /api/v1/support/tickets/<ticket_number>/
    static func ticketDetail(ticketNumber: String) -> Endpoint {
        Endpoint(path: "/api/v1/support/tickets/\(ticketNumber)/", method: .get)
    }

    /// GET /api/v1/support/tickets/<ticket_number>/messages/
    static func ticketMessages(ticketNumber: String) -> Endpoint {
        Endpoint(path: "/api/v1/support/tickets/\(ticketNumber)/messages/", method: .get)
    }

    /// POST /api/v1/support/tickets/<ticket_number>/messages/
    static func sendTicketMessage(ticketNumber: String, message: String) -> Endpoint {
        Endpoint(
            path: "/api/v1/support/tickets/\(ticketNumber)/messages/",
            method: .post,
            body: AnyEncodable(SendTicketMessageRequest(body: message))
        )
    }

    /// POST /api/v1/support/tickets/<ticket_number>/close/
    static func closeTicket(ticketNumber: String) -> Endpoint {
        Endpoint(path: "/api/v1/support/tickets/\(ticketNumber)/close/", method: .post)
    }

    /// GET /api/v1/support/faq/
    static let supportFAQs = Endpoint(path: "/api/v1/support/faq/", method: .get)

    /// POST /api/v1/support/faq/<id>/helpful/
    static func faqVote(id: Int, isHelpful: Bool) -> Endpoint {
        Endpoint(
            path: "/api/v1/support/faq/\(id)/helpful/",
            method: .post,
            body: AnyEncodable(FAQVoteRequest(isHelpful: isHelpful))
        )
    }

    // MARK: - Activity Endpoints

    /// GET /api/v1/activity/feed/
    static func activityFeed(page: Int = 1, pageSize: Int = 20, type: String = "") -> Endpoint {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "page",      value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)"),
        ]
        if !type.isEmpty { items.append(URLQueryItem(name: "type", value: type)) }
        return Endpoint(path: "/api/v1/activity/feed/", method: .get, queryItems: items)
    }

    /// GET /api/v1/activity/stats/
    static let activityStats = Endpoint(path: "/api/v1/activity/stats/", method: .get)

    /// GET /api/v1/activity/jobs/
    static func activityJobs(role: String = "", status: String = "", page: Int = 1, pageSize: Int = 20) -> Endpoint {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "page",      value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)"),
        ]
        if !role.isEmpty   { items.append(URLQueryItem(name: "role",   value: role)) }
        if !status.isEmpty { items.append(URLQueryItem(name: "status", value: status)) }
        return Endpoint(path: "/api/v1/activity/jobs/", method: .get, queryItems: items)
    }

    /// GET /api/v1/activity/payments/
    static func activityPayments(page: Int = 1, pageSize: Int = 20) -> Endpoint {
        let items: [URLQueryItem] = [
            URLQueryItem(name: "page",      value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)"),
        ]
        return Endpoint(path: "/api/v1/activity/payments/", method: .get, queryItems: items)
    }

    /// GET /api/v1/activity/reviews/
    static func activityReviews(direction: String = "", page: Int = 1, pageSize: Int = 20) -> Endpoint {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "page",      value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)"),
        ]
        if !direction.isEmpty { items.append(URLQueryItem(name: "direction", value: direction)) }
        return Endpoint(path: "/api/v1/activity/reviews/", method: .get, queryItems: items)
    }
}

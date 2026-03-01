//
//  Config.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import Foundation

nonisolated enum AppEnvironment: Sendable {
    case development
    case staging
    case production

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}

nonisolated struct Config: Sendable {
    // MARK: - API Base URL
    // Resolution order:
    //   1. Info.plist key "API_BASE_URL" (set via xcconfig or build settings)
    //   2. Scheme environment variable "API_BASE_URL" (for per-run overrides)
    //   3. Compile-time default per environment
    static var apiBaseURL: URL {
        // 1. Info.plist - single source of truth for release/CI builds
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           !plistValue.isEmpty,
           let url = URL(string: plistValue) {
            return url
        }
        // 2. Environment variable - useful for Xcode scheme overrides
        if let envValue = ProcessInfo.processInfo.environment["API_BASE_URL"],
           !envValue.isEmpty,
           let url = URL(string: envValue) {
            return url
        }
        // 3. Compile-time default
        switch AppEnvironment.current {
        case .development:
            return URL(string: "http://10.0.0.238:8000")!
        case .staging:
            return URL(string: "https://staging-api.konektly.com")!
        case .production:
            return URL(string: "https://api.konektly.com")!
        }
    }

    // MARK: - API Version Path
    static let apiVersion = "/api/v1"

    static var apiBaseURLWithVersion: URL {
        apiBaseURL.appendingPathComponent(apiVersion)
    }

    // MARK: - Feature Flags
    /// When true, the OTP screen accepts a plain numeric code without Firebase (dev mode only)
    static var isDevOTPFallbackEnabled: Bool {
        AppEnvironment.current == .development
    }

    // MARK: - Timeouts
    static let requestTimeout: TimeInterval = 30
    static let resourceTimeout: TimeInterval = 60
}

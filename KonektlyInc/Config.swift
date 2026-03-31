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

nonisolated enum AppleMode: String, Sendable {
    case sandbox
    case production
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
            return URL(string: "https://api.konektly.ca")!
        }
    }

    // MARK: - API Version Path
    static let apiVersion = "/api/v1"

    static var apiBaseURLWithVersion: URL {
        apiBaseURL.appendingPathComponent(apiVersion)
    }

    // MARK: - Apple Subscription Mode
    // Resolution order:
    //   1. Info.plist key "APPLE_MODE" (preferred for build flavors)
    //   2. Scheme environment variable "APPLE_MODE" (run-time override)
    //   3. Compile-time default (Debug=sandbox, Release=production)
    static var appleMode: AppleMode {
        if let plistValue = Bundle.main.object(forInfoDictionaryKey: "APPLE_MODE") as? String,
           let mode = AppleMode(rawValue: plistValue.lowercased()) {
            return mode
        }
        if let envValue = ProcessInfo.processInfo.environment["APPLE_MODE"],
           let mode = AppleMode(rawValue: envValue.lowercased()) {
            return mode
        }
        #if DEBUG
        return .sandbox
        #else
        return .production
        #endif
    }

    // MARK: - WebSocket Base URL
    /// Converts http→ws, https→wss for WebSocket connections
    static var wsBaseURL: URL {
        let httpString = apiBaseURL.absoluteString
        let wsString: String
        if httpString.hasPrefix("https://") {
            wsString = "wss://" + httpString.dropFirst("https://".count)
        } else if httpString.hasPrefix("http://") {
            wsString = "ws://" + httpString.dropFirst("http://".count)
        } else {
            wsString = httpString
        }
        return URL(string: wsString)!
    }

    // MARK: - Timeouts
    static let requestTimeout: TimeInterval = 30
    static let resourceTimeout: TimeInterval = 60
}

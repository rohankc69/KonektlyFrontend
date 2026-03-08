//
//  LocationManager.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-07.
//

import Foundation
import Combine
import CoreLocation

// MARK: - Location Authorization Status

enum LocationAuthStatus {
    case notDetermined
    case denied
    case restricted
    case authorized
}

// MARK: - Location Manager

/// Wraps CLLocationManager and exposes the device's current location as a published property.
/// Use this to pass `lat`/`lng` to `JobStore.fetchNearbyJobs(lat:lng:)`.
///
/// Usage:
/// ```swift
/// @StateObject private var locationManager = LocationManager()
///
/// .task {
///     locationManager.requestAuthorization()
///     if let coord = await locationManager.currentCoordinate() {
///         await jobStore.fetchNearbyJobs(lat: coord.latitude, lng: coord.longitude)
///     }
/// }
/// ```
@MainActor
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Published

    @Published private(set) var authStatus: LocationAuthStatus = .notDetermined
    @Published private(set) var coordinate: CLLocationCoordinate2D? = nil
    @Published private(set) var isLocating: Bool = false
    @Published private(set) var locationError: String? = nil

    // MARK: - Private

    private let manager = CLLocationManager()
    private var continuations: [CheckedContinuation<CLLocationCoordinate2D?, Never>] = []

    // MARK: - Init

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        updateAuthStatus(manager.authorizationStatus)
    }

    // MARK: - Public API

    /// Request When-In-Use location authorization from the OS.
    /// Call this once when the user navigates to a location-dependent screen.
    func requestAuthorization() {
        guard authStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// Requests a one-shot current location update.
    /// - Returns: The device's current coordinate, or `nil` if permission is denied / error occurred.
    func currentCoordinate() async -> CLLocationCoordinate2D? {
        // If we already have a recent fix and are authorized, return it immediately
        if let coord = coordinate, authStatus == .authorized {
            return coord
        }

        guard authStatus == .authorized else {
            locationError = authStatus == .denied
                ? "Location access is disabled. Enable it in Settings to see nearby jobs."
                : nil
            return nil
        }

        isLocating = true
        locationError = nil
        defer { isLocating = false }

        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
            manager.requestLocation()
        }
    }

    // MARK: - Private helpers

    private func updateAuthStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            authStatus = .notDetermined
        case .denied:
            authStatus = .denied
        case .restricted:
            authStatus = .restricted
        case .authorizedWhenInUse, .authorizedAlways:
            authStatus = .authorized
        @unknown default:
            authStatus = .notDetermined
        }
    }

    private func resumeAllContinuations(with coordinate: CLLocationCoordinate2D?) {
        let pending = continuations
        continuations.removeAll()
        for cont in pending {
            cont.resume(returning: coordinate)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            updateAuthStatus(manager.authorizationStatus)
            // If permission was just granted and there are pending continuations, request location
            if authStatus == .authorized && !continuations.isEmpty {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            let coord = location.coordinate
            self.coordinate = coord
            self.locationError = nil
            print("[LOCATION] Updated: lat=\(coord.latitude) lng=\(coord.longitude)")
            resumeAllContinuations(with: coord)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in
            let clError = error as? CLError
            switch clError?.code {
            case .denied:
                locationError = "Location access is disabled. Enable it in Settings."
                authStatus = .denied
            case .locationUnknown:
                // Transient — CLLocationManager will keep trying, just surface a soft message
                locationError = "Unable to determine location. Please try again."
            default:
                locationError = error.localizedDescription
            }
            print("[LOCATION] Error: \(error.localizedDescription)")
            resumeAllContinuations(with: nil)
        }
    }
}

//
//  LocationService.swift
//  Shadow Lens
//
//  Foreground-only CoreLocation wrapper. Location is used solely to compute
//  solar position locally; it is never transmitted anywhere.
//

import Foundation
import CoreLocation
import Combine

/// Describes the current authorization + data state of location services so the
/// UI can respond gracefully to denial, restriction, and "not yet asked".
enum LocationState: Equatable {
    case notDetermined
    case denied
    case restricted
    case unavailable          // services off device-wide
    case authorized(CLLocation)
    case authorizedNoFix      // authorized but no fix yet

    var isUsable: Bool {
        if case .authorized = self { return true }
        return false
    }
}

/// A simple resolved location used by the solar math, with a human label.
struct ResolvedLocation: Equatable {
    var latitude: Double
    var longitude: Double
    var name: String
    /// True when this came from the device GPS rather than a manual fallback.
    var isLive: Bool
}

@MainActor
final class LocationService: NSObject, ObservableObject {

    @Published private(set) var state: LocationState = .notDetermined
    @Published private(set) var lastLocation: CLLocation?
    @Published private(set) var placemarkName: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var hasRequestedThisSession = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Reflect the initial authorization without prompting.
        syncState(for: manager.authorizationStatus)
    }

    /// Requests foreground (when-in-use) authorization if it has not been
    /// determined yet. Safe to call repeatedly.
    func requestAuthorization() {
        guard CLLocationManager.locationServicesEnabled() || manager.authorizationStatus == .notDetermined else {
            state = .unavailable
            return
        }
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else {
            syncState(for: manager.authorizationStatus)
            startIfAuthorized()
        }
    }

    /// Begins location updates when authorized.
    func start() {
        startIfAuthorized()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    private func startIfAuthorized() {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        manager.startUpdatingLocation()
    }

    private func syncState(for status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            state = .notDetermined
        case .denied:
            state = .denied
        case .restricted:
            state = .restricted
        case .authorizedAlways, .authorizedWhenInUse:
            if let loc = lastLocation {
                state = .authorized(loc)
            } else {
                state = .authorizedNoFix
            }
        @unknown default:
            state = .unavailable
        }
    }

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            if let p = placemarks?.first {
                let parts = [p.locality, p.administrativeArea, p.country].compactMap { $0 }
                self.placemarkName = parts.isEmpty ? nil : parts.joined(separator: ", ")
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.syncState(for: status)
            self.startIfAuthorized()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = loc
            self.state = .authorized(loc)
            self.reverseGeocode(loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            // A transient failure should not clobber a previously good fix.
            if self.lastLocation == nil {
                self.state = .authorizedNoFix
            }
        }
    }
}

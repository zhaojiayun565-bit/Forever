import CoreLocation
import Foundation
import Observation
import UIKit

enum AmbientDataError: LocalizedError {
    case locationDenied
    case locationUnknown
    case locationServicesUnavailable

    var errorDescription: String? {
        switch self {
        case .locationDenied: "Location access was denied."
        case .locationUnknown: "Could not determine the current location."
        case .locationServicesUnavailable: "Location services are unavailable."
        }
    }
}

/// Location and battery sampling for Supabase / widgets.
@MainActor
@Observable
final class AmbientDataManager: NSObject {
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var authorizationContinuation: CheckedContinuation<Void, Error>?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    /// Enables battery monitoring and requests When In Use location authorization (call early, e.g. after sign-in).
    func requestWhenInUseAuthorizationFirst() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        locationManager.requestWhenInUseAuthorization()
    }

    /// Returns battery charge 0–100; turns on monitoring if needed.
    func fetchCurrentBatteryLevel() -> Int {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let raw = UIDevice.current.batteryLevel
        guard raw >= 0 else { return 0 }
        return Int((raw * 100).rounded(.toNearestOrAwayFromZero))
    }

    /// Samples GPS + battery and writes to the current user's profile.
    func syncData() async throws {
        let battery = fetchCurrentBatteryLevel()
        try await ensureLocationAuthorized()
        let location = try await fetchCurrentLocation()
        try await SupabaseManager.shared.updateAmbientData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            batteryLevel: battery
        )
    }

    private func ensureLocationAuthorized() async throws {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                authorizationContinuation = continuation
                locationManager.requestWhenInUseAuthorization()
            }
        case .authorizedAlways, .authorizedWhenInUse:
            return
        case .denied, .restricted:
            throw AmbientDataError.locationDenied
        @unknown default:
            throw AmbientDataError.locationServicesUnavailable
        }
    }

    private func fetchCurrentLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    @MainActor
    private func resumeAuthorization(_ result: Result<Void, Error>) {
        guard let cont = authorizationContinuation else { return }
        authorizationContinuation = nil
        cont.resume(with: result)
    }

    @MainActor
    private func resumeLocation(_ result: Result<CLLocation, Error>) {
        guard let cont = locationContinuation else { return }
        locationContinuation = nil
        cont.resume(with: result)
    }

    @MainActor
    private static func mapLocationFailure(_ error: Error) -> Error {
        let ns = error as NSError
        if ns.domain == kCLErrorDomain, ns.code == CLError.denied.rawValue {
            return AmbientDataError.locationDenied
        }
        if ns.domain == kCLErrorDomain, ns.code == CLError.locationUnknown.rawValue {
            return AmbientDataError.locationUnknown
        }
        return error
    }
}

extension AmbientDataManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let status = manager.authorizationStatus
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                resumeAuthorization(.success(()))
            case .denied, .restricted:
                resumeAuthorization(.failure(AmbientDataError.locationDenied))
            case .notDetermined:
                break
            @unknown default:
                resumeAuthorization(.failure(AmbientDataError.locationServicesUnavailable))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let loc = locations.last else {
                resumeLocation(.failure(AmbientDataError.locationUnknown))
                return
            }
            resumeLocation(.success(loc))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            resumeLocation(.failure(Self.mapLocationFailure(error)))
        }
    }
}

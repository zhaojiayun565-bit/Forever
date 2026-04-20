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

@MainActor
@Observable
final class AmbientDataManager: NSObject, CLLocationManagerDelegate {
    static let shared = AmbientDataManager()

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    var authorizationStatus: CLAuthorizationStatus

    override private init() {
        // Initialize status safely
        self.authorizationStatus = .notDetermined
        super.init()
        
        locationManager.delegate = self
        self.authorizationStatus = locationManager.authorizationStatus
        
        // CRITICAL FIX: Removed `allowsBackgroundLocationUpdates` to prevent the Xcode Capability crash.
        // Standard significant location changes / widget updates will still function without it.
    }

    /// Called purely by the Onboarding UI to trigger the system prompt safely
    func requestLocationAuthorizationFirst() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        // Requesting "When In Use" is the safest crash-proof method for iOS 15+.
        // Users can upgrade to "Always" via settings or a subsequent prompt later.
        locationManager.requestWhenInUseAuthorization()
    }

    func fetchCurrentBatteryLevel() -> Int {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let raw = UIDevice.current.batteryLevel
        guard raw >= 0 else { return 0 }
        return Int((raw * 100).rounded(.toNearestOrAwayFromZero))
    }

    func syncData() async throws {
        let battery = fetchCurrentBatteryLevel()

        guard authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse else {
            throw AmbientDataError.locationDenied
        }
        
        let location = try await fetchCurrentLocation()
        
        try await SupabaseManager.shared.updateAmbientData(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            batteryLevel: battery
        )
    }

    private func fetchCurrentLocation() async throws -> CLLocation {
        if locationContinuation != nil {
            locationContinuation?.resume(throwing: CancellationError())
            locationContinuation = nil
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    // MARK: - Delegate
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let loc = locations.last else {
                locationContinuation?.resume(throwing: AmbientDataError.locationUnknown)
                locationContinuation = nil
                return
            }
            locationContinuation?.resume(returning: loc)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            let ns = error as NSError
            var mappedError: Error = error
            if ns.domain == kCLErrorDomain {
                if ns.code == CLError.denied.rawValue { mappedError = AmbientDataError.locationDenied }
                if ns.code == CLError.locationUnknown.rawValue { mappedError = AmbientDataError.locationUnknown }
            }
            
            locationContinuation?.resume(throwing: mappedError)
            locationContinuation = nil
        }
    }
}

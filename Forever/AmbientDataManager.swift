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
    // 1. SINGLE SOURCE OF TRUTH
    static let shared = AmbientDataManager()

    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    
    // Expose status so UI can react natively
    var authorizationStatus: CLAuthorizationStatus

    override private init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        // CRITICAL: Required for Lock Screen widgets to update distance in the background
        locationManager.allowsBackgroundLocationUpdates = true
    }

    /// Called purely by the Onboarding UI to trigger the system prompt safely
    func requestAlwaysAuthorizationFirst() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        locationManager.requestAlwaysAuthorization()
    }

    func fetchCurrentBatteryLevel() -> Int {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let raw = UIDevice.current.batteryLevel
        guard raw >= 0 else { return 0 }
        return Int((raw * 100).rounded(.toNearestOrAwayFromZero))
    }

    func syncData() async throws {
        let battery = fetchCurrentBatteryLevel()
        
        // 2. SAFE AUTHORIZATION CHECK (No fragile continuations)
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
        // 3. CONTINUATION SAFETY: Prevent Swift traps if called rapidly
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

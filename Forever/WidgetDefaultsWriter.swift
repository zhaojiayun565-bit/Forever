import CoreLocation
import Foundation
import WidgetKit

/// Widget kind identifiers matching the CoupleWidget target definitions.
enum WidgetKind {
    static let distanceHome = "StatusWidget"
    static let distanceLockScreen = "DistanceLockScreenWidget"
    static let drawing = "DrawingWidget"
    static let lockScreenMessage = "LockScreenMessageWidget"
    static let daysTogether = "DaysTogetherWidget"

    static let distance: Set<String> = [distanceHome, distanceLockScreen]
    static let all: Set<String> = [distanceHome, distanceLockScreen, drawing, lockScreenMessage, daysTogether]
}

/// Writes widget-facing values to the App Group and reloads only the widget kinds whose data changed,
/// so routine refreshes don't burn the daily WidgetKit reload budget.
struct WidgetDefaultsWriter {
    /// Coordinate changes smaller than this (~50 m) don't count as movement for widget reloads.
    private static let coordinateEpsilon = 0.0005

    let defaults: UserDefaults
    private(set) var kindsToReload: Set<String> = []

    init?() {
        guard let defaults = AppGroup.defaults else { return nil }
        self.defaults = defaults
    }

    /// Stores `value` (or removes the key when nil) and marks `kinds` for reload if it changed.
    mutating func set<Value: Equatable>(_ value: Value?, forKey key: String, affects kinds: Set<String>) {
        if let value {
            guard defaults.object(forKey: key) as? Value != value else { return }
            defaults.set(value, forKey: key)
        } else {
            guard defaults.object(forKey: key) != nil else { return }
            defaults.removeObject(forKey: key)
        }
        kindsToReload.formUnion(kinds)
    }

    /// Stores a coordinate pair, ignoring GPS jitter below `coordinateEpsilon`.
    mutating func setCoordinate(_ coordinate: CLLocationCoordinate2D?, latitudeKey: String, longitudeKey: String) {
        let oldLat = defaults.object(forKey: latitudeKey) as? Double
        let oldLon = defaults.object(forKey: longitudeKey) as? Double
        if let coordinate, let oldLat, let oldLon,
           abs(coordinate.latitude - oldLat) < Self.coordinateEpsilon,
           abs(coordinate.longitude - oldLon) < Self.coordinateEpsilon {
            return
        }
        set(coordinate?.latitude, forKey: latitudeKey, affects: WidgetKind.distance)
        set(coordinate?.longitude, forKey: longitudeKey, affects: WidgetKind.distance)
    }

    /// Marks widget kinds for reload without writing a value (e.g. an avatar file was replaced).
    mutating func markChanged(_ kinds: Set<String>) {
        kindsToReload.formUnion(kinds)
    }

    /// Reloads the affected widget timelines.
    func reload() {
        if kindsToReload == WidgetKind.all {
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            kindsToReload.forEach { WidgetCenter.shared.reloadTimelines(ofKind: $0) }
        }
    }
}

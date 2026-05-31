import CoreLocation
import MapKit

/// Reverse-geocodes a coordinate to a human-readable place name.
enum GeocodingHelper {
    /// Returns a display name for the given coordinate, or nil if lookup fails.
    static func placeName(for coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location),
                  let mapItem = try? await request.mapItems.first
            else { return nil }
            return mapItem.name
                ?? mapItem.address?.shortAddress
                ?? mapItem.address?.fullAddress
        } else {
            let geocoder = CLGeocoder()
            guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
                return nil
            }
            return placemark.areasOfInterest?.first
                ?? placemark.name
                ?? placemark.locality
        }
    }

    /// Returns the coordinate for a map search result item.
    static func coordinate(for mapItem: MKMapItem) -> CLLocationCoordinate2D {
        if #available(iOS 26.0, *) {
            return mapItem.location.coordinate
        } else {
            return mapItem.placemark.coordinate
        }
    }
}

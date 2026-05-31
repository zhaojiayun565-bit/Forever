import Foundation
import MapKit
import Observation

/// Wraps `MKLocalSearchCompleter` for place autocomplete.
@Observable
class LocationSearchService: NSObject, MKLocalSearchCompleterDelegate {
    var searchQuery = "" {
        didSet {
            completer.queryFragment = searchQuery
        }
    }
    var completions: [MKLocalSearchCompletion] = []

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        completer.resultTypes = [.address, .pointOfInterest]
        super.init()
        completer.delegate = self
    }

    /// Biases autocomplete toward the visible map region.
    func updateRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.completions = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.completions = []
            print("🚨 Location search failed: \(error.localizedDescription)")
        }
    }
}

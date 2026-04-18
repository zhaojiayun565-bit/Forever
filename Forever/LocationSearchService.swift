import Combine
import Foundation
import MapKit

/// Wraps `MKLocalSearchCompleter` for place autocomplete.
final class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = ""
    @Published var completions: [MKLocalSearchCompletion] = []

    private let completer: MKLocalSearchCompleter
    private var cancellable: AnyCancellable?

    override init() {
        completer = MKLocalSearchCompleter()
        completer.resultTypes = [.address, .pointOfInterest]
        super.init()
        completer.delegate = self

        cancellable = $searchQuery.assign(to: \.queryFragment, on: completer)
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.completions = completer.results
        }
    }
}

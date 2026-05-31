import SwiftUI
import MapKit
import CoreLocation
import UIKit

struct LocationPickerView: View {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var locationName: String?
    @Environment(\.dismiss) private var dismiss

    @State private var searchService = LocationSearchService()
    @State private var position: MapCameraPosition = .automatic
    @State private var currentCenter: CLLocationCoordinate2D?
    @FocusState private var isSearchFocused: Bool

    // Track exact POI names when searched.
    @State private var explicitPlaceName: String? = nil
    @State private var explicitPlaceCoordinate: CLLocationCoordinate2D? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) { }
                .onMapCameraChange { context in
                    currentCenter = context.region.center
                    searchService.updateRegion(context.region)

                    // If they drag away from searched POI, stop forcing its name.
                    if let center = currentCenter, let searchedCoord = explicitPlaceCoordinate {
                        let centerLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)
                        let searchedLoc = CLLocation(latitude: searchedCoord.latitude, longitude: searchedCoord.longitude)
                        if centerLoc.distance(from: searchedLoc) > 150 {
                            explicitPlaceName = nil
                        }
                    }
                }
                .ignoresSafeArea()
                .onTapGesture {
                    isSearchFocused = false
                }

            VStack {
                Spacer()
                Image(systemName: "mappin")
                    .font(.system(size: 40))
                    .foregroundStyle(.pink)
                    .padding(.bottom, 40)
                Spacer()
            }
            .allowsHitTesting(false)

            LocationSearchBar(
                searchService: searchService,
                isFocused: $isSearchFocused,
                onSelect: selectCompletion
            )

            VStack {
                Spacer()
                Button {
                    Task { await confirmLocation() }
                } label: {
                    Text("Confirm Location")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.pink)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Choose Location")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func selectCompletion(_ completion: MKLocalSearchCompletion) {
        searchService.searchQuery = completion.title

        let request = MKLocalSearch.Request(completion: completion)
        Task {
            let search = MKLocalSearch(request: request)
            if let response = try? await search.start(), let item = response.mapItems.first {
                let coordinate = GeocodingHelper.coordinate(for: item)
                explicitPlaceName = completion.title
                explicitPlaceCoordinate = coordinate
                position = .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        latitudinalMeters: 5000,
                        longitudinalMeters: 5000
                    )
                )
            }
        }
    }

    private func confirmLocation() async {
        guard let center = currentCenter else { return }
        selectedCoordinate = center

        if let explicit = explicitPlaceName {
            locationName = explicit
        } else if let geocoded = await GeocodingHelper.placeName(for: center) {
            locationName = geocoded
        } else {
            locationName = searchService.searchQuery.isEmpty ? "Selected Location" : searchService.searchQuery
        }

        dismiss()
    }
}

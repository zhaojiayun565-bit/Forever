import SwiftUI
import MapKit
import CoreLocation
import UIKit

struct LocationPickerView: View {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var locationName: String?
    var onManualConfirm: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var searchService = LocationSearchService()
    @State private var position: MapCameraPosition
    @State private var currentCenter: CLLocationCoordinate2D?
    @FocusState private var isSearchFocused: Bool

    // Track exact POI names when searched.
    @State private var explicitPlaceName: String? = nil
    @State private var explicitPlaceCoordinate: CLLocationCoordinate2D? = nil

    init(
        selectedCoordinate: Binding<CLLocationCoordinate2D?>,
        locationName: Binding<String?>,
        onManualConfirm: (() -> Void)? = nil
    ) {
        _selectedCoordinate = selectedCoordinate
        _locationName = locationName
        self.onManualConfirm = onManualConfirm
        let start = selectedCoordinate.wrappedValue ?? CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
        _currentCenter = State(initialValue: start)
        _position = State(
            initialValue: .region(
                MKCoordinateRegion(center: start, latitudinalMeters: 8_000, longitudinalMeters: 8_000)
            )
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {}
                .mapStyle(.standard)
                .onMapCameraChange(frequency: .onEnd) { context in
                    currentCenter = context.region.center
                    searchService.updateRegion(context.region)
                    unstickPOINameIfNeeded(center: context.region.center)
                }
                .ignoresSafeArea(edges: .bottom)
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
                        .font(ForeverFont.cta(.headline))
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
        .task {
            guard selectedCoordinate == nil else { return }
            let center = await AmbientDataManager.shared.mapCenterCoordinate()
            currentCenter = center
            position = .region(
                MKCoordinateRegion(center: center, latitudinalMeters: 8_000, longitudinalMeters: 8_000)
            )
        }
    }

    private func unstickPOINameIfNeeded(center: CLLocationCoordinate2D) {
        guard let searchedCoord = explicitPlaceCoordinate else { return }
        let centerLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let searchedLoc = CLLocation(latitude: searchedCoord.latitude, longitude: searchedCoord.longitude)
        if centerLoc.distance(from: searchedLoc) > 150 {
            explicitPlaceName = nil
            explicitPlaceCoordinate = nil
        }
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
                currentCenter = coordinate
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

        onManualConfirm?()
        dismiss()
    }
}

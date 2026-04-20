import CoreLocation
import MapKit
import SwiftUI
import UIKit

struct LocationPickerView: View {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var locationName: String?
    @Environment(\.dismiss) private var dismiss

    @State private var searchService = LocationSearchService()
    @State private var position: MapCameraPosition = .automatic
    @State private var currentCenter: CLLocationCoordinate2D?
    @State private var isSearching = false

    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {}
                .onMapCameraChange { context in
                    currentCenter = context.region.center
                }
                .ignoresSafeArea()

            VStack {
                Spacer()
                Image(systemName: "mappin")
                    .font(.system(size: 40))
                    .foregroundStyle(.pink)
                    .padding(.bottom, 40)
                Spacer()
            }
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                TextField("Search a city or place...", text: $searchService.searchQuery)
                    .padding(12)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.12), radius: 5)
                    .padding()
                    .onTapGesture { isSearching = true }

                if isSearching, !searchService.completions.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(searchService.completions.enumerated()), id: \.offset) { _, completion in
                                Button {
                                    selectCompletion(completion)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(completion.title)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(completion.subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 12)
                                }
                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.12), radius: 5)
                }
            }

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
        isSearching = false
        searchService.searchQuery = completion.title

        let request = MKLocalSearch.Request(completion: completion)
        Task {
            let search = MKLocalSearch(request: request)
            if let response = try? await search.start(), let item = response.mapItems.first {
                position = .region(
                    MKCoordinateRegion(
                        center: item.placemark.coordinate,
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

        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let first: CLPlacemark? = await withCheckedContinuation { cont in
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                cont.resume(returning: placemarks?.first)
            }
        }

        if let first {
            locationName = first.locality ?? first.name ?? "Selected Location"
        } else {
            locationName = searchService.searchQuery.isEmpty ? "Selected Location" : searchService.searchQuery
        }

        dismiss()
    }
}

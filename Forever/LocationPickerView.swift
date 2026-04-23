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
    @State private var isSearching = false
    
    // Track exact POI names when searched.
    @State private var explicitPlaceName: String? = nil
    @State private var explicitPlaceCoordinate: CLLocationCoordinate2D? = nil
    
    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) { }
                .onMapCameraChange { context in
                    currentCenter = context.region.center
                    
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
                    .shadow(radius: 5)
                    .padding()
                    .onTapGesture { isSearching = true }
                
                if isSearching && !searchService.completions.isEmpty {
                    List(Array(searchService.completions.enumerated()), id: \.offset) { _, completion in
                        VStack(alignment: .leading) {
                            Text(completion.title).font(.headline)
                            Text(completion.subtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .onTapGesture { selectCompletion(completion) }
                    }
                    .listStyle(.plain)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .frame(maxHeight: 300)
                    .shadow(radius: 5)
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
                // Lock in the exact restaurant/POI name.
                explicitPlaceName = completion.title
                explicitPlaceCoordinate = item.placemark.coordinate
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
        
        if let explicit = explicitPlaceName {
            // Priority 1: Use exactly what they searched for.
            locationName = explicit
        } else {
            // Priority 2: Standard reverse geocoding.
            let geocoder = CLGeocoder()
            let location = CLLocation(latitude: center.latitude, longitude: center.longitude)
            if let placemarks = try? await geocoder.reverseGeocodeLocation(location), let first = placemarks.first {
                locationName = first.areasOfInterest?.first ?? first.name ?? first.locality ?? searchService.searchQuery
            } else {
                locationName = searchService.searchQuery.isEmpty ? "Selected Location" : searchService.searchQuery
            }
        }
        
        dismiss()
    }
}

import MapKit
import SwiftUI
import UIKit

struct LocationPickerView: View {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Environment(\.dismiss) private var dismiss

    @State private var position: MapCameraPosition = .automatic
    @State private var currentCenter: CLLocationCoordinate2D?
    @State private var searchQuery = ""

    var body: some View {
        ZStack {
            Map(position: $position) {
                // Pin is fixed in the UI; map center is the chosen coordinate.
            }
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

            VStack {
                TextField("Search a city or place...", text: $searchQuery)
                    .padding(12)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.12), radius: 5)
                    .padding()
                    .onSubmit {
                        searchLocation()
                    }
                Spacer()
            }

            VStack {
                Spacer()
                Button {
                    selectedCoordinate = currentCenter
                    dismiss()
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

    private func searchLocation() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
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
}

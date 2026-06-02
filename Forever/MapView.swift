import MapKit
import SwiftUI
import UIKit

struct MapDashboardView: View {
    @Environment(AppStateManager.self) private var state
    @State private var showingAddMemory = false
    @State private var selectedMemory: CoupleMemory?
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Map(position: $position) {
                    ForEach(state.memories) { memory in
                        Annotation("", coordinate: memory.coordinate) {
                            MemoryMapPinLabel(imageURL: memory.imageUrls.first, note: memory.note)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedMemory = memory
                                }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea(edges: .top)
                .onChange(of: state.newlyAddedLocation) { _, newLocation in
                    if let coord = newLocation {
                        let center = CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation(.easeInOut(duration: 1.5)) {
                                position = .region(
                                    MKCoordinateRegion(
                                        center: center,
                                        latitudinalMeters: 5000,
                                        longitudinalMeters: 5000
                                    )
                                )
                            }
                            state.newlyAddedLocation = nil
                        }
                    }
                }

                MemoryMapFABButton(accent: .pink) {
                    showingAddMemory = true
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
            .task {
                await state.loadMemories()
            }
            .refreshable {
                await state.loadMemories()
            }
            .fullScreenCover(isPresented: $showingAddMemory) {
                AddMemoryView()
                    .environment(state)
            }
            .fullScreenCover(item: $selectedMemory) { memory in
                MemoryDetailView(memory: memory)
                    .environment(state)
            }
        }
    }
}

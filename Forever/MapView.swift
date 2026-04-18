import SwiftUI
import MapKit

struct MapDashboardView: View {
    @Environment(AppStateManager.self) private var state

    var body: some View {
        NavigationStack {
            Map {
                ForEach(state.memories) { memory in
                    Annotation("", coordinate: memory.coordinate) {
                        AsyncImage(url: memory.imageUrl) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Color.pink.opacity(0.3)
                            }
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 3.5))
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .mapStyle(.standard(elevation: .realistic))
            .task {
                await state.loadMemories()
            }
        }
    }
}

import SwiftUI
import MapKit

struct MapDashboardView: View {
    @Environment(AppStateManager.self) private var state
    @State private var showingAddMemory = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
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
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea(edges: .top)

                Button {
                    showingAddMemory = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Color.pink)
                        .clipShape(Circle())
                        .shadow(color: .pink.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
                .accessibilityLabel("Add memory")
            }
            .task {
                await state.loadMemories()
            }
            .sheet(isPresented: $showingAddMemory) {
                AddMemoryView()
                    .environment(state)
            }
        }
    }
}

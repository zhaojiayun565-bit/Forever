import MapKit
import SwiftUI
import UIKit

struct MapDashboardView: View {
    @Environment(AppStateManager.self) private var state
    @State private var showingAddMemory = false
    @State private var selectedMemory: CoupleMemory?
    @State private var openCommentsOnAppear = false
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
                                    openCommentsOnAppear = false
                                    selectedMemory = memory
                                }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .ignoresSafeArea(edges: .top)
                .task(id: state.newlyAddedLocation) {
                    guard let coord = state.newlyAddedLocation else { return }
                    let center = CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
                    guard (try? await Task.sleep(for: .milliseconds(500))) != nil else { return }
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

                MemoryMapFABButton(accent: .pink) {
                    showingAddMemory = true
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await state.loadMemories()
                openPendingMemoryIfNeeded()
            }
            .refreshable {
                await state.loadMemories()
            }
            .navigationDestination(isPresented: $showingAddMemory) {
                AddMemoryView()
                    .environment(state)
            }
            .navigationDestination(item: $selectedMemory) { memory in
                MemoryDetailView(memory: memory, initiallyShowComments: openCommentsOnAppear)
                    .environment(state)
            }
            .onChange(of: state.pendingMemoryOpen) { _, _ in
                openPendingMemoryIfNeeded()
            }
            .onChange(of: state.memories.map(\.id)) { _, _ in
                openPendingMemoryIfNeeded()
            }
        }
    }

    /// Opens a memory from a comment notification once the map has that pin.
    private func openPendingMemoryIfNeeded() {
        guard let pending = state.pendingMemoryOpen else { return }
        guard let memory = state.memories.first(where: { $0.id == pending.memoryId }) else { return }
        openCommentsOnAppear = pending.showComments
        selectedMemory = memory
        state.pendingMemoryOpen = nil
    }
}

import Kingfisher
import MapKit
import SwiftUI
import UIKit

struct MapDashboardView: View {
    @Environment(AppStateManager.self) private var state
    @State private var showingAddMemory = false
    @State private var selectedMemory: CoupleMemory?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Map {
                    ForEach(state.memories) { memory in
                        Annotation("", coordinate: memory.coordinate) {
                            HStack(spacing: 8) {
                                KFImage.url(memory.imageUrls.first)
                                    .placeholder { Color.pink.opacity(0.3) }
                                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 100, height: 100)))
                                    .scaleFactor(UIScreen.main.scale)
                                    .cacheOriginalImage()
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 3.5))
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)

                                if let note = memory.note, !note.isEmpty {
                                    Text(note)
                                        .font(.system(.caption, design: .rounded).weight(.bold))
                                        .lineLimit(1)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Capsule())
                                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                                        .frame(maxWidth: 140, alignment: .leading)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedMemory = memory
                            }
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

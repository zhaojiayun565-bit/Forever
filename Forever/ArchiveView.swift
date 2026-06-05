import Kingfisher
import SwiftUI
import UIKit

struct ArchiveView: View {
    var embedded: Bool = false

    @Environment(AppStateManager.self) private var state
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = ArchiveViewModel()
    @State private var selectedDrawing: ArchivedDrawing?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        if embedded {
            archiveContent
        } else {
            NavigationStack {
                archiveContent
            }
        }
    }

    private var archiveContent: some View {
        Group {
            if viewModel.isLoading && viewModel.drawings.isEmpty {
                ProgressView()
            } else if viewModel.drawings.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.drawings) { drawing in
                            Button {
                                selectedDrawing = drawing
                            } label: {
                                archiveCard(for: drawing)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Archive")
        .refreshable {
            await viewModel.load(coupleId: state.currentCouple?.id)
        }
        .task {
            await viewModel.load(coupleId: state.currentCouple?.id)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.load(coupleId: state.currentCouple?.id) }
            }
        }
        .fullScreenCover(item: $selectedDrawing) { drawing in
            ArchiveDrawingViewer(drawing: drawing, onClose: { selectedDrawing = nil })
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.quaternary)
            Text("No drawings yet")
                .font(ForeverFont.header(.title2))
            Text("Sent drawings from the board will appear here for both of you.")
                .font(ForeverFont.body(.body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    /// Grid cell with image, author label, and relative date.
    private func archiveCard(for drawing: ArchivedDrawing) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ArchiveNoteCard(url: drawing.imageUrl)
                .frame(height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(authorLabel(for: drawing))
                    .font(ForeverFont.subheader(.subheadline))
                    .foregroundStyle(.primary)
                Text(drawing.createdAt, style: .relative)
                    .font(ForeverFont.caption())
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// "You" when the current user sent it; otherwise the partner's name.
    private func authorLabel(for drawing: ArchivedDrawing) -> String {
        if drawing.authorId == state.currentUser?.id {
            return String(localized: "You")
        }
        return state.partnerProfile?.displayName ?? String(localized: "Partner")
    }
}

// MARK: - Full-screen viewer

private struct ArchiveDrawingViewer: View {
    let drawing: ArchivedDrawing
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            KFImage.url(drawing.imageUrl)
                .placeholder { ProgressView() }
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .navigationTitle(drawing.createdAt.formatted(date: .abbreviated, time: .shortened))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done", action: onClose)
                    }
                }
        }
    }
}

// MARK: - Note card (Kingfisher + downsampled thumbnail)

struct ArchiveNoteCard: View {
    let url: URL

    var body: some View {
        KFImage.url(url)
            .placeholder {
                ZStack {
                    Color.gray.opacity(0.1)
                    ProgressView()
                }
            }
            .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 300, height: 300)))
            .scaleFactor(UIScreen.main.scale)
            .cacheOriginalImage()
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}

#Preview("Archive note card") {
    ArchiveNoteCard(url: URL(string: "https://picsum.photos/400")!)
        .frame(width: 160, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12))
}

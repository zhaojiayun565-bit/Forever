import Kingfisher
import PhotosUI
import SwiftUI
import UIKit

/// One photo in the new/edit memory strip: a new image, an existing remote URL, or both.
struct MemoryPhotoDraft: Identifiable, Equatable {
    let id: UUID
    var image: UIImage?
    var url: URL?

    init(id: UUID = UUID(), image: UIImage? = nil, url: URL? = nil) {
        self.id = id
        self.image = image
        self.url = url
    }
}

/// Horizontal photo picker with add and remove. Swipe to scroll.
struct MemoryPhotoStrip: View {
    @Binding var photos: [MemoryPhotoDraft]
    var maxCount: Int = 10
    var onPickedItems: ([PhotosPickerItem]) async -> Void = { _ in }

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPicker = false

    private let photoSize: CGFloat = 100
    private var remainingSlots: Int { max(0, maxCount - photos.count) }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if remainingSlots > 0 {
                    addButton
                }

                ForEach(photos) { photo in
                    photoCell(photo)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
            .padding(.leading, 6)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private var addButton: some View {
        Button {
            Task {
                await PhotoLibraryAuthorizationManager.requestIfNeeded()
                showPicker = true
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .frame(width: photoSize, height: photoSize)
                .foregroundStyle(.pink)
                .background(Color.pink.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .photosPicker(
            isPresented: $showPicker,
            selection: $pickerItems,
            maxSelectionCount: remainingSlots,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                await append(items)
                pickerItems = []
            }
        }
        .accessibilityLabel("Add photos")
    }

    private func photoCell(_ photo: MemoryPhotoDraft) -> some View {
        ZStack(alignment: .topLeading) {
            thumbnail(for: photo)

            EditModeRemoveBadge {
                photos.removeAll { $0.id == photo.id }
            }
            .offset(x: -6, y: -6)
        }
    }

    @ViewBuilder
    private func thumbnail(for photo: MemoryPhotoDraft) -> some View {
        Group {
            if let image = photo.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = photo.url {
                KFImage.url(url)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.pink.opacity(0.1)
            }
        }
        .frame(width: photoSize, height: photoSize)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func append(_ items: [PhotosPickerItem]) async {
        var added: [MemoryPhotoDraft] = []
        for item in items {
            guard photos.count + added.count < maxCount else { break }
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                added.append(MemoryPhotoDraft(image: image))
            }
        }
        photos.append(contentsOf: added)
        await onPickedItems(items)
    }
}

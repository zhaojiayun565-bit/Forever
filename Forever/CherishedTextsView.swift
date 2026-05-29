import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct CherishedTextsView: View {
    @Query(sort: \CherishedText.dateAdded, order: .reverse) private var cherishedTexts: [CherishedText]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var showImportDialog = false
    @State private var showPicker = false
    @State private var pickerFilter: PHPickerFilter = .screenshots

    private var filteredCherishedTexts: [CherishedText] {
        guard !searchText.isEmpty else { return cherishedTexts }
        return cherishedTexts.filter {
            $0.extractedText.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var pendingOCRItems: [CherishedText] {
        cherishedTexts.filter { $0.extractedText.isEmpty }
    }

    var body: some View {
        Group {
            if cherishedTexts.isEmpty && !isImporting {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)],
                        spacing: 3
                    ) {
                        ForEach(filteredCherishedTexts) { cherishedText in
                            NavigationLink {
                                CherishedTextDetailView(
                                    allTexts: filteredCherishedTexts,
                                    initialID: cherishedText.id
                                )
                            } label: {
                                ScreenshotTile(imageData: cherishedText.imageData)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .searchable(text: $searchText, prompt: "Search memories...")
                .task {
                    await processPendingOCR()
                }
            }
        }
        .navigationTitle("Cherished Texts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showImportDialog = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.pink)
                }
                .disabled(isImporting)
            }
        }
        .confirmationDialog("Import Memory", isPresented: $showImportDialog, titleVisibility: .visible) {
            Button("Browse Screenshots") {
                pickerFilter = .screenshots
                showPicker = true
            }
            Button("Browse All Photos") {
                pickerFilter = .images
                showPicker = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPicker, selection: $selectedItem, matching: pickerFilter)
        .overlay {
            if isImporting {
                importOverlay
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task { await importScreenshot(from: newItem) }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Cherished Texts", systemImage: "heart.text.square")
        } description: {
            Text("Tap + to import a screenshot.")
        } actions: {
            Button {
                showImportDialog = true
            } label: {
                Text("Import Screenshot")
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .disabled(isImporting)
        }
    }

    private var importOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text("Reading screenshot…")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    /// Runs OCR for items saved without extracted text.
    @MainActor
    private func processPendingOCR() async {
        let pending = pendingOCRItems
        guard !pending.isEmpty else { return }

        var didUpdate = false
        for item in pending {
            do {
                item.extractedText = try await VisionHelper.extractText(from: item.imageData)
                didUpdate = true
            } catch {
                continue
            }
        }

        if didUpdate {
            try? modelContext.save()
        }
    }

    /// Loads a screenshot, persists it, then runs pending OCR.
    @MainActor
    private func importScreenshot(from item: PhotosPickerItem) async {
        isImporting = true
        defer {
            isImporting = false
            selectedItem = nil
        }

        guard let imageData = try? await item.loadTransferable(type: ScreenshotImageData.self)?.data else { return }

        let cherishedText = CherishedText(
            imageData: imageData,
            extractedText: ""
        )

        modelContext.insert(cherishedText)
        try? modelContext.save()

        await processPendingOCR()
    }
}

// MARK: - Detail View

struct CherishedTextDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Local mutable copy so removing an item updates the pager immediately
    // without accessing a tombstoned SwiftData object.
    @State private var items: [CherishedText]
    @State private var currentID: UUID
    @State private var showDeleteConfirmation = false

    init(allTexts: [CherishedText], initialID: UUID) {
        _items = State(initialValue: allTexts)
        _currentID = State(initialValue: initialID)
    }

    private var currentIndex: Int? {
        items.firstIndex { $0.id == currentID }
    }

    var body: some View {
        TabView(selection: $currentID) {
            ForEach(items) { text in
                ZStack {
                    Color.black.ignoresSafeArea()

                    if let uiImage = UIImage(data: text.imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .tag(text.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.black, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .confirmationDialog(
            "Delete this memory?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteCurrentAndNavigate()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This screenshot will be permanently removed.")
        }
    }

    /// Removes the current item from both the local pager and the SwiftData store.
    private func deleteCurrentAndNavigate() {
        guard let idx = currentIndex else { return }

        let itemToDelete = items[idx]

        // Determine the next item to land on before mutating the array.
        let nextID: UUID? = {
            if idx + 1 < items.count { return items[idx + 1].id }
            if idx - 1 >= 0 { return items[idx - 1].id }
            return nil
        }()

        // Remove from local array first so the TabView updates cleanly.
        items.remove(at: idx)
        modelContext.delete(itemToDelete)
        try? modelContext.save()

        if let nextID {
            currentID = nextID
        } else {
            dismiss()
        }
    }
}

// MARK: - Supporting Types

private struct ScreenshotTile: View {
    let imageData: Data

    var body: some View {
        if let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .aspectRatio(9 / 19.5, contentMode: .fill)
                .clipped()
                .contentShape(Rectangle())
        }
    }
}

private struct ScreenshotImageData: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { ScreenshotImageData(data: $0) }
        DataRepresentation(importedContentType: .jpeg) { ScreenshotImageData(data: $0) }
        DataRepresentation(importedContentType: .png) { ScreenshotImageData(data: $0) }
    }
}

#Preview {
    NavigationStack {
        CherishedTextsView()
    }
    .modelContainer(SharedDatabase.shared)
}

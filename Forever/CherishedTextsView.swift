import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct CherishedTextsView: View {
    @Query(sort: \CherishedText.dateAdded, order: .reverse) private var cherishedTexts: [CherishedText]
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isImporting = false

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
                            ScreenshotTile(imageData: cherishedText.imageData)
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
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .screenshots
                ) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.pink)
                }
                .disabled(isImporting)
            }
        }
        .overlay {
            if isImporting {
                importOverlay
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
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
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .screenshots
            ) {
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

    /// Runs OCR in the main app for items saved without extracted text (e.g. from the Share Extension).
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

    /// Loads a screenshot and persists it; OCR runs lazily via `processPendingOCR()`.
    @MainActor
    private func importScreenshot(from item: PhotosPickerItem) async {
        isImporting = true
        defer {
            isImporting = false
            selectedPhoto = nil
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

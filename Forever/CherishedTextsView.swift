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
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            if cherishedTexts.isEmpty && !isImporting {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(filteredCherishedTexts) { cherishedText in
                            CherishedTextCard(cherishedText: cherishedText)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
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
            Text("Share a screenshot from Messages, or tap + to import an older one.")
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

private struct CherishedTextCard: View {
    let cherishedText: CherishedText

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let uiImage = UIImage(data: cherishedText.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.04))
            }

            VStack(alignment: .leading, spacing: 8) {
                if cherishedText.extractedText.isEmpty {
                    Text("Extracting text…")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(cherishedText.extractedText)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.primary)
                        .lineLimit(5)
                        .multilineTextAlignment(.leading)
                }

                Text(cherishedText.dateAdded.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 10)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.6), lineWidth: 0.5)
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

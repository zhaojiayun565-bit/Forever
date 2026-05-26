import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct CherishedTextsView: View {
    @Query(sort: \CherishedText.dateAdded, order: .reverse) private var cherishedTexts: [CherishedText]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            Group {
                if cherishedTexts.isEmpty && !isImporting {
                    ContentUnavailableView(
                        "No Cherished Texts",
                        systemImage: "text.bubble",
                        description: Text("Save screenshots from the share sheet, or add one here.")
                    )
                } else {
                    List {
                        ForEach(cherishedTexts) { cherishedText in
                            CherishedTextRow(cherishedText: cherishedText)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Cherished Texts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .screenshots
                    ) {
                        Image(systemName: "plus")
                    }
                    .disabled(isImporting)
                }
            }
            .overlay {
                if isImporting {
                    ProgressView("Extracting text…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                guard let newItem else { return }
                Task { await importScreenshot(from: newItem) }
            }
        }
    }

    /// Loads a screenshot, runs OCR, and persists the result to the shared SwiftData store.
    private func importScreenshot(from item: PhotosPickerItem) async {
        isImporting = true
        defer {
            isImporting = false
            selectedPhoto = nil
        }

        guard let imageData = try? await item.loadTransferable(type: ScreenshotImageData.self)?.data else { return }

        do {
            let extractedText = try await VisionHelper.extractText(from: imageData)
            let cherishedText = CherishedText(
                imageData: imageData,
                extractedText: extractedText
            )
            modelContext.insert(cherishedText)
            try modelContext.save()
        } catch {
            // OCR or persistence failed.
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

private struct CherishedTextRow: View {
    let cherishedText: CherishedText

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let uiImage = UIImage(data: cherishedText.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if cherishedText.extractedText.isEmpty {
                Text("No text detected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(cherishedText.extractedText)
                    .font(.body)
                    .lineLimit(6)
            }

            Text(cherishedText.dateAdded.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CherishedTextsView()
        .modelContainer(SharedDatabase.shared)
}

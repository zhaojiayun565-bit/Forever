import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct CherishedTextsView: View {
    @Query(sort: \CherishedText.dateAdded, order: .reverse) private var cherishedTexts: [CherishedText]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppStateManager.self) private var state

    @State private var searchText = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var showImportDialog = false
    @State private var showPicker = false
    @State private var pickerFilter: PHPickerFilter = .screenshots
    @State private var realtimeTask: Task<Void, Never>?

    private var filteredCherishedTexts: [CherishedText] {
        guard !searchText.isEmpty else { return cherishedTexts }
        return cherishedTexts.filter {
            $0.extractedText.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Search-filtered list with duplicate IDs removed for stable ForEach identity.
    private var displayCherishedTexts: [CherishedText] {
        dedupeByID(filteredCherishedTexts)
    }

    private var pendingOCRItems: [CherishedText] {
        cherishedTexts.filter { $0.extractedText.isEmpty }
    }

    private var syncTaskKey: String {
        let couplePart = state.currentCouple?.id.uuidString ?? "solo"
        let userPart = state.currentUser?.id.uuidString ?? "anon"
        return "\(couplePart)-\(userPart)"
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
                        ForEach(displayCherishedTexts) { cherishedText in
                            NavigationLink {
                                CherishedTextDetailView(
                                    allTexts: displayCherishedTexts,
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
        .task(id: syncTaskKey) {
            await startSyncAndRealtime()
        }
        .onDisappear {
            realtimeTask?.cancel()
            realtimeTask = nil
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
                    .font(ForeverFont.subheader(.subheadline))
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    /// Runs OCR for items saved without extracted text, then syncs if paired.
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
            await syncIfPaired()
        }
    }

    /// Loads a screenshot, persists it, then runs pending OCR and sync.
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

    /// Starts Realtime listener and performs an initial merge when paired.
    @MainActor
    private func startSyncAndRealtime() async {
        realtimeTask?.cancel()
        realtimeTask = nil

        guard let coupleId = state.currentCouple?.id else { return }

        await CherishedTextSync.mergeRemoteAndPushLocal(coupleId: coupleId)

        realtimeTask = SupabaseManager.shared.listenForCherishedTextChanges(coupleId: coupleId) {
            await CherishedTextSync.mergeRemoteAndPushLocal(coupleId: coupleId)
        }
    }

    /// Pushes unsynced local rows when the user is authenticated and paired.
    @MainActor
    private func syncIfPaired() async {
        guard let coupleId = state.currentCouple?.id else { return }
        await CherishedTextSync.mergeRemoteAndPushLocal(coupleId: coupleId)
    }
}

// MARK: - Detail View

struct CherishedTextDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStateManager.self) private var state

    // Local mutable copy so removing an item updates the pager immediately
    // without accessing a tombstoned SwiftData object.
    @State private var items: [CherishedText]
    @State private var currentID: UUID
    @State private var showDeleteConfirmation = false

    init(allTexts: [CherishedText], initialID: UUID) {
        _items = State(initialValue: dedupeByID(allTexts))
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
                Task { await deleteCurrentAndNavigate() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This screenshot will be permanently removed from your Cherished Texts (it will not be deleted from your native Photos library).")
        }
    }

    /// Removes the current item locally and from Supabase when synced.
    @MainActor
    private func deleteCurrentAndNavigate() async {
        guard let idx = currentIndex else { return }

        let itemToDelete = items[idx]

        let nextID: UUID? = {
            if idx + 1 < items.count { return items[idx + 1].id }
            if idx - 1 >= 0 { return items[idx - 1].id }
            return nil
        }()

        items.remove(at: idx)

        await CherishedTextSync.delete(itemToDelete, coupleId: state.currentCouple?.id)

        if let nextID {
            currentID = nextID
        } else {
            dismiss()
        }
    }
}

// MARK: - Sync

@MainActor
private enum CherishedTextSync {
    private static let supabase = SupabaseManager.shared
    private static var mergeChain: Task<Void, Never>?

    /// Merges remote rows into SwiftData, removes partner-deleted items, and pushes local unsynced rows.
    static func mergeRemoteAndPushLocal(coupleId: UUID) async {
        let previous = mergeChain
        let task = Task { @MainActor in
            await previous?.value
            let modelContext = SharedDatabase.context
            await pullRemoteChanges(coupleId: coupleId, modelContext: modelContext)
            await pushUnsyncedLocal(coupleId: coupleId, modelContext: modelContext)
            try? modelContext.save()
        }
        mergeChain = task
        await task.value
    }

    /// Fetches remote rows and reconciles local SwiftData state.
    private static func pullRemoteChanges(coupleId: UUID, modelContext: ModelContext) async {
        do {
            deduplicateExistingLocalItems(in: modelContext)
            try? modelContext.save()

            let remote = try await supabase.fetchCherishedTexts(coupleId: coupleId)
            let remoteIDs = Set(remote.map(\.id))
            let localItems = try modelContext.fetch(FetchDescriptor<CherishedText>())

            for item in localItems where item.isSynced && !remoteIDs.contains(item.id) {
                modelContext.delete(item)
            }

            for row in remote {
                if !(try fetchLocalItems(withId: row.id, in: modelContext)).isEmpty { continue }

                guard let imageData = try? await downloadImage(from: row.imageURL) else { continue }
                if !(try fetchLocalItems(withId: row.id, in: modelContext)).isEmpty { continue }

                let cherishedText = CherishedText(
                    id: row.id,
                    imageData: imageData,
                    extractedText: row.extractedText,
                    dateAdded: row.createdAt,
                    isSynced: true,
                    remoteImageURL: row.imageURL.absoluteString
                )
                modelContext.insert(cherishedText)
            }
        } catch {
            print("🚨 Cherished text sync pull error (coupleId=\(coupleId)): \(error)")
        }
    }

    /// Removes duplicate local rows, keeping the synced or newest entry per id.
    private static func deduplicateExistingLocalItems(in modelContext: ModelContext) {
        guard let localItems = try? modelContext.fetch(FetchDescriptor<CherishedText>()) else { return }

        let grouped = Dictionary(grouping: localItems, by: \.id)
        for duplicates in grouped.values where duplicates.count > 1 {
            let keeper = duplicates.max { lhs, rhs in
                if lhs.isSynced != rhs.isSynced { return !lhs.isSynced && rhs.isSynced }
                return lhs.dateAdded < rhs.dateAdded
            }!
            for item in duplicates where item !== keeper {
                modelContext.delete(item)
            }
        }
    }

    /// Returns all local rows matching an id (should be zero or one after dedupe).
    private static func fetchLocalItems(withId id: UUID, in modelContext: ModelContext) throws -> [CherishedText] {
        let targetId = id
        let descriptor = FetchDescriptor<CherishedText>(
            predicate: #Predicate { $0.id == targetId }
        )
        return try modelContext.fetch(descriptor)
    }

    /// Uploads local unsynced rows to Supabase.
    private static func pushUnsyncedLocal(coupleId: UUID, modelContext: ModelContext) async {
        guard let creatorId = await supabase.currentUserId() else { return }

        let unsyncedDescriptor = FetchDescriptor<CherishedText>(
            predicate: #Predicate { $0.isSynced == false }
        )
        guard let unsynced = try? modelContext.fetch(unsyncedDescriptor), !unsynced.isEmpty else { return }

        for item in unsynced {
            do {
                let jpegData = jpegPayload(from: item.imageData)
                let imageURL = try await supabase.uploadCherishedTextImage(
                    data: jpegData,
                    coupleId: coupleId,
                    textId: item.id
                )
                do {
                    try await supabase.insertCherishedText(
                        id: item.id,
                        coupleId: coupleId,
                        creatorId: creatorId,
                        imageURL: imageURL,
                        extractedText: item.extractedText,
                        createdAt: item.dateAdded
                    )
                } catch {
                    let exists = try await supabase.cherishedTextExists(id: item.id, coupleId: coupleId)
                    guard exists else { throw error }
                }
                item.isSynced = true
                item.remoteImageURL = imageURL.absoluteString
            } catch {
                print("🚨 Cherished text sync push error (coupleId=\(coupleId), id=\(item.id)): \(error)")
            }
        }
    }

    /// Deletes from Supabase (when synced) and always removes the local SwiftData row.
    static func delete(_ item: CherishedText, coupleId: UUID?) async {
        let modelContext = SharedDatabase.context
        if item.isSynced, coupleId != nil {
            let remoteURL = item.remoteImageURL.flatMap(URL.init(string:))
            do {
                try await supabase.deleteCherishedText(id: item.id, imageURL: remoteURL)
            } catch {
                print("🚨 Cherished text delete error: \(error)")
            }
        }

        modelContext.delete(item)
        try? modelContext.save()
    }

    private static func downloadImage(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    /// Normalizes screenshot data to JPEG for storage upload.
    private static func jpegPayload(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.85) else {
            return data
        }
        return jpeg
    }
}

// MARK: - Supporting Types

/// Keeps the first occurrence of each id for stable SwiftUI identity.
private func dedupeByID(_ items: [CherishedText]) -> [CherishedText] {
    var seen = Set<UUID>()
    return items.filter { seen.insert($0.id).inserted }
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
    .environment(AppStateManager())
}

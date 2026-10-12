import SwiftUI
import PhotosUI
import MapKit
import UIKit

struct EditMemoryView: View {
    let memory: CoupleMemory
    let onSaveComplete: () -> Void

    @Environment(AppStateManager.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var photos: [MemoryPhotoDraft]

    @State private var date: Date
    @State private var showingCalendarSheet = false
    @State private var showingLocationPicker = false
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var locationName: String?
    @State private var note: String

    @State private var isSaving = false
    @State private var errorMessage: String?

    init(memory: CoupleMemory, onSaveComplete: @escaping () -> Void) {
        self.memory = memory
        self.onSaveComplete = onSaveComplete
        _photos = State(initialValue: memory.imageUrls.map { MemoryPhotoDraft(url: $0) })
        _date = State(initialValue: memory.createdAt)
        _coordinate = State(initialValue: memory.coordinate)
        _note = State(initialValue: memory.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MemoryPhotoStrip(photos: $photos)
                }

                Section {
                        HStack {
                            Text("Date")
                            Spacer()
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { showingCalendarSheet = true }

                        Button {
                            showingLocationPicker = true
                        } label: {
                            HStack {
                                Text("Location")
                                Spacer()
                                Text(locationName ?? "Edit")
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(.primary)

                        TextField("Write a note...", text: $note, axis: .vertical)
                            .lineLimit(4 ... 8)
                    }
            }
            .navigationTitle("Edit Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await saveEdits() } }
                        .font(ForeverFont.cta(.body))
                        .disabled(photos.isEmpty || coordinate == nil || isSaving)
                }
            }
            .onAppear { fetchLocationName() }
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        ProgressView("Saving...")
                            .padding()
                            .background(Color(uiColor: .systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .alert(
                "Save Failed",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An error occurred.")
            }
            .sheet(isPresented: $showingCalendarSheet) {
                NavigationStack {
                    DatePicker("Select Date", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .navigationTitle("Choose Date")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingCalendarSheet = false }
                            }
                        }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingLocationPicker) {
                NavigationStack {
                    LocationPickerView(selectedCoordinate: $coordinate, locationName: $locationName)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showingLocationPicker = false }
                            }
                        }
                }
            }
        }
    }

    private func fetchLocationName() {
        guard locationName == nil, let coord = coordinate else { return }
        Task {
            if let name = await GeocodingHelper.placeName(for: coord) {
                locationName = name
            }
        }
    }

    private func saveEdits() async {
        guard let creatorId = state.currentUser?.id else {
            errorMessage = "Authentication error."
            return
        }
        guard let lat = coordinate?.latitude, let lng = coordinate?.longitude else {
            errorMessage = "Please select a valid location."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let coupleIdForMemory = state.currentCouple?.id
            let uploadedByID = try await withThrowingTaskGroup(of: (UUID, URL).self) { group in
                for photo in photos {
                    guard let image = photo.image else { continue }
                    group.addTask {
                        let data = try await ImageEncoding.jpeg(image, quality: 0.7)
                        let url = try await SupabaseManager.shared.uploadMemoryImage(
                            data: data,
                            coupleId: coupleIdForMemory,
                            creatorId: creatorId
                        )
                        return (photo.id, url)
                    }
                }
                var urls: [UUID: URL] = [:]
                for try await (id, url) in group { urls[id] = url }
                return urls
            }

            let finalUrls: [URL] = photos.compactMap { photo in
                photo.url ?? uploadedByID[photo.id]
            }
            guard !finalUrls.isEmpty else {
                errorMessage = "Please keep at least one photo."
                return
            }

            try await SupabaseManager.shared.updateMemory(
                id: memory.id,
                imageUrls: finalUrls,
                lat: lat,
                lng: lng,
                date: date,
                note: note
            )
            await state.loadMemories()
            dismiss()
            onSaveComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

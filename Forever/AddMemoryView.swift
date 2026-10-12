import MapKit
import PhotosUI
import SwiftUI
import UIKit
import os

struct AddMemoryView: View {
    @Environment(AppStateManager.self) private var state
    @Environment(\.dismiss) private var dismiss

    var onboardingSaveAction: ((UIImage, String, CLLocationCoordinate2D) -> Void)?
    var initialCoordinate: CLLocationCoordinate2D?

    @State private var photos: [MemoryPhotoDraft] = []
    @State private var date = Date()
    @State private var showingCalendarSheet = false
    @State private var showingLocationPicker = false
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var locationName: String?
    @State private var note = ""

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didManuallyPickLocation = false
    @State private var didManuallyPickDate = false

    private var selectedImages: [UIImage] {
        photos.compactMap(\.image)
    }

    var body: some View {
        Form {
            Section {
                MemoryPhotoStrip(photos: $photos) { items in
                    await applyPhotoMetadata(from: items)
                }
            }

            Section {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingCalendarSheet = true
                    }

                    Button {
                        showingLocationPicker = true
                    } label: {
                        HStack {
                            Text("Location")
                            Spacer()
                            Text(locationName ?? "Choose")
                                .foregroundStyle(locationName != nil ? Color.secondary : Color.pink)
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
        .navigationTitle("New Memory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await saveMemory() }
                }
                .font(ForeverFont.cta(.body))
                .disabled(selectedImages.isEmpty || coordinate == nil || isSaving)
            }
        }
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
            Text(errorMessage ?? "An unknown error occurred.")
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
                            Button("Done") {
                                didManuallyPickDate = true
                                showingCalendarSheet = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingLocationPicker) {
            NavigationStack {
                LocationPickerView(
                    selectedCoordinate: $coordinate,
                    locationName: $locationName,
                    onManualConfirm: { didManuallyPickLocation = true }
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingLocationPicker = false }
                    }
                }
            }
        }
        .task {
            guard let initialCoordinate, coordinate == nil else { return }
            coordinate = initialCoordinate
            if let name = await GeocodingHelper.placeName(for: initialCoordinate) {
                locationName = name
            }
        }
    }

    /// Applies GPS and capture date from the first selected photo with PHAsset metadata.
    private func applyPhotoMetadata(from items: [PhotosPickerItem]) async {
        let metadata = PhotoLibraryMetadataReader.metadata(
            forItemIdentifiers: items.compactMap(\.itemIdentifier)
        )

        if !didManuallyPickLocation, let coordinate = metadata.coordinate {
            self.coordinate = coordinate
            locationName = await GeocodingHelper.placeName(for: coordinate)
        }

        if !didManuallyPickDate, let creationDate = metadata.creationDate {
            date = Calendar.current.startOfDay(for: creationDate)
        }
    }

    private func saveMemory() async {
        if let onboardingSaveAction {
            guard let image = selectedImages.first, let coordinate else {
                errorMessage = "Please add a photo and choose a location."
                return
            }
            onboardingSaveAction(image, note, coordinate)
            dismiss()
            return
        }

        guard let lat = coordinate?.latitude, let lng = coordinate?.longitude else {
            errorMessage = "Please select a valid location."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await state.saveMemory(
                images: selectedImages,
                note: note,
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                date: date
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            Log.data.error("Save Error: \(String(describing: error))")
        }
    }
}

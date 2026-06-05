import MapKit
import PhotosUI
import SwiftUI
import UIKit

struct AddMemoryView: View {
    @Environment(AppStateManager.self) private var state
    @Environment(\.dismiss) private var dismiss

    var onboardingSaveAction: ((UIImage, String, CLLocationCoordinate2D) -> Void)?
    var initialCoordinate: CLLocationCoordinate2D?

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var date = Date()
    @State private var showingCalendarSheet = false
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var locationName: String?
    @State private var note = ""

    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            PhotosPicker(selection: $selectedItems, maxSelectionCount: 10, matching: .images) {
                                VStack {
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .bold))
                                }
                                .frame(width: 100, height: 100)
                                .foregroundStyle(.pink)
                                .background(Color.pink.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .onChange(of: selectedItems) { _, items in
                                Task { await loadImages(from: items) }
                            }

                            ForEach(Array(selectedImages.enumerated()), id: \.offset) { _, img in
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
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

                    NavigationLink {
                        LocationPickerView(selectedCoordinate: $coordinate, locationName: $locationName)
                    } label: {
                        HStack {
                            Text("Location")
                            Spacer()
                            Text(locationName ?? "Choose")
                                .foregroundStyle(locationName != nil ? Color.secondary : Color.pink)
                                .lineLimit(1)
                        }
                    }

                    TextField("Write a note...", text: $note, axis: .vertical)
                        .lineLimit(4 ... 8)
                }
            }
            .navigationTitle("New Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
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
                                Button("Done") { showingCalendarSheet = false }
                            }
                        }
                }
                .presentationDetents([.medium])
            }
            .task {
                guard let initialCoordinate, coordinate == nil else { return }
                coordinate = initialCoordinate
                if let name = await GeocodingHelper.placeName(for: initialCoordinate) {
                    locationName = name
                }
            }
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        var loaded: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                loaded.append(uiImage)
            }
        }
        selectedImages = loaded
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
            print("🚨 Save Error: \(error)")
        }
    }
}

import MapKit
import PhotosUI
import SwiftUI
import UIKit

struct AddMemoryView: View {
    @Environment(AppStateManager.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    @State private var date = Date()
    @State private var showDatePickerSheet = false

    @State private var coordinate: CLLocationCoordinate2D?
    @State private var locationName: String?

    @State private var note = ""
    @State private var isSaving = false

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
                    .onTapGesture { showDatePickerSheet = true }

                    NavigationLink {
                        LocationPickerView(selectedCoordinate: $coordinate, locationName: $locationName)
                    } label: {
                        HStack {
                            Text("Location")
                            Spacer()
                            Text(locationName ?? "Choose")
                                .foregroundStyle(locationName != nil ? Color.secondary : Color.pink)
                        }
                    }

                    TextField("Write a note...", text: $note, axis: .vertical)
                        .lineLimit(4 ... 8)
                }
            }
            .navigationTitle("New Memory")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDatePickerSheet) {
                NavigationStack {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                        .onChange(of: date) { _, _ in
                            showDatePickerSheet = false
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .navigationTitle("Date")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showDatePickerSheet = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
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
                    .fontWeight(.bold)
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
        guard let lat = coordinate?.latitude, let lng = coordinate?.longitude,
              let coupleId = state.currentCouple?.id, let creatorId = state.currentUser?.id else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            var uploadedUrls: [URL] = []
            for image in selectedImages {
                if let data = image.jpegData(compressionQuality: 0.8) {
                    let url = try await SupabaseManager.shared.uploadMemoryImage(data: data, coupleId: coupleId)
                    uploadedUrls.append(url)
                }
            }
            guard !uploadedUrls.isEmpty else { return }

            try await SupabaseManager.shared.insertMemory(
                coupleId: coupleId,
                creatorId: creatorId,
                imageUrls: uploadedUrls,
                lat: lat,
                lng: lng,
                date: date,
                note: note
            )
            await state.loadMemories()
            dismiss()
        } catch {
            print("🚨 Save Error: \(error)")
        }
    }
}

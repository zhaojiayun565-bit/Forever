import MapKit
import PhotosUI
import SwiftUI
import UIKit

struct AddMemoryView: View {
    @Environment(AppStateManager.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var date = Date()
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var note = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        if let selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 250)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .listRowInsets(EdgeInsets())
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 40))
                                Text("Add a Photo")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .foregroundStyle(.pink)
                            .background(Color.pink.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task {
                            guard let newItem else { return }
                            if let data = try? await newItem.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                selectedImage = image
                            }
                        }
                    }
                }
                .listRowBackground(Color.clear)

                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    NavigationLink {
                        LocationPickerView(selectedCoordinate: $coordinate)
                    } label: {
                        HStack {
                            Text("Location")
                            Spacer()
                            if coordinate != nil {
                                Text("Selected").foregroundStyle(.secondary)
                            } else {
                                Text("Choose").foregroundStyle(.pink)
                            }
                        }
                    }

                    TextField("Write a note...", text: $note, axis: .vertical)
                        .lineLimit(4 ... 8)
                }
            }
            .navigationTitle("New Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveMemory() }
                    }
                    .fontWeight(.bold)
                    .disabled(selectedImage == nil || coordinate == nil || isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        ProgressView("Saving...")
                            .padding()
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    private func saveMemory() async {
        guard let image = selectedImage,
              let data = image.jpegData(compressionQuality: 0.8),
              let lat = coordinate?.latitude,
              let lng = coordinate?.longitude,
              let coupleId = state.currentCouple?.id,
              let creatorId = state.currentUser?.id else { return }

        isSaving = true
        defer { isSaving = false }

        do {
            let url = try await SupabaseManager.shared.uploadMemoryImage(data: data, coupleId: coupleId)
            try await SupabaseManager.shared.insertMemory(
                coupleId: coupleId,
                creatorId: creatorId,
                imageUrl: url,
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

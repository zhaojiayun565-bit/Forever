import SwiftUI
import PhotosUI
import MapKit
import Kingfisher
import UIKit

struct EditMemoryView: View {
    let memory: CoupleMemory
    let onSaveComplete: () -> Void
    
    @Environment(AppStateManager.self) private var state
    @Environment(\.dismiss) private var dismiss
    
    @State private var existingUrls: [URL]
    @State private var newSelectedItems: [PhotosPickerItem] = []
    @State private var newSelectedImages: [UIImage] = []
    
    @State private var date: Date
    @State private var showingCalendarSheet = false
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var locationName: String?
    @State private var note: String
    
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    init(memory: CoupleMemory, onSaveComplete: @escaping () -> Void) {
        self.memory = memory
        self.onSaveComplete = onSaveComplete
        _existingUrls = State(initialValue: memory.imageUrls)
        _date = State(initialValue: memory.createdAt)
        _coordinate = State(initialValue: memory.coordinate)
        _note = State(initialValue: memory.note ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            PhotosPicker(selection: $newSelectedItems, maxSelectionCount: 10, matching: .images) {
                                VStack {
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .bold))
                                }
                                .frame(width: 100, height: 100)
                                .foregroundStyle(.pink)
                                .background(Color.pink.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .onChange(of: newSelectedItems) { _, items in
                                Task { await loadImages(from: items) }
                            }
                            
                            ForEach(Array(newSelectedImages.enumerated()), id: \.offset) { _, img in
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            ForEach(existingUrls, id: \.self) { url in
                                ZStack(alignment: .topLeading) {
                                    KFImage.url(url)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    EditModeRemoveBadge {
                                        existingUrls.removeAll { $0 == url }
                                    }
                                    .offset(x: -6, y: -6)
                                }
                            }
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                        .padding(.leading, 6)
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
                    .onTapGesture { showingCalendarSheet = true }
                    
                    NavigationLink {
                        LocationPickerView(selectedCoordinate: $coordinate, locationName: $locationName)
                    } label: {
                        HStack {
                            Text("Location")
                            Spacer()
                            Text(locationName ?? "Edit")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
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
                        .fontWeight(.bold)
                        .disabled((existingUrls.isEmpty && newSelectedImages.isEmpty) || coordinate == nil || isSaving)
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
        }
    }
    
    private func loadImages(from items: [PhotosPickerItem]) async {
        var loaded: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                loaded.append(uiImage)
            }
        }
        newSelectedImages = loaded
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
            var finalUrls = existingUrls
            let coupleIdForMemory = state.currentCouple?.id
            if !newSelectedImages.isEmpty {
                let uploadedUrls = try await withThrowingTaskGroup(of: URL.self) { group in
                    for image in newSelectedImages {
                        if let data = image.jpegData(compressionQuality: 0.7) {
                            group.addTask {
                                try await SupabaseManager.shared.uploadMemoryImage(
                                    data: data,
                                    coupleId: coupleIdForMemory,
                                    creatorId: creatorId
                                )
                            }
                        }
                    }
                    var urls: [URL] = []
                    for try await url in group { urls.append(url) }
                    return urls
                }
                finalUrls.append(contentsOf: uploadedUrls)
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

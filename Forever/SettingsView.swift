import SwiftUI
import WidgetKit
import PhotosUI
import UIKit

private enum DistanceUnitOption: String, CaseIterable {
    case miles = "mi"
    case kilometers = "km"

    var label: String {
        switch self {
        case .miles:
            return "Miles (mi)"
        case .kilometers:
            return "Kilometers (km)"
        }
    }
}

struct SettingsView: View {
    @Environment(AppStateManager.self) private var state
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var displayName = ""
    @State private var anniversary = Date()
    @State private var isSaving = false
    @State private var isShowingUnpairAlert = false
    @AppStorage("distanceUnit") private var distanceUnit = DistanceUnitOption.miles.rawValue
    @State private var showPairingSheet = false
    @State private var showPhotoOptions = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var isUploadingAvatar = false
    @State private var avatarError: String?

    private var normalizedDistanceUnit: String {
        DistanceUnitOption(rawValue: distanceUnit)?.rawValue ?? DistanceUnitOption.miles.rawValue
    }

    private func syncDistanceUnitToWidgetDefaults() {
        guard let defaults = UserDefaults(suiteName: "group.com.jiayunzhao.Forever") else { return }
        let unit = normalizedDistanceUnit
        if defaults.string(forKey: "distanceUnit") != unit {
            defaults.set(unit, forKey: "distanceUnit")
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Button {
                            showPhotoOptions = true
                        } label: {
                            ZStack {
                                AvatarView(
                                    url: state.currentUser?.avatarUrl.flatMap { URL(string: $0) },
                                    name: displayName.isEmpty ? (state.currentUser?.displayName ?? "Me") : displayName,
                                    localImage: state.myAvatarImage,
                                    size: 96
                                )
                                if isUploadingAvatar {
                                    Circle()
                                        .fill(.black.opacity(0.35))
                                        .frame(width: 96, height: 96)
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    if let avatarError {
                        Text(avatarError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowBackground(Color.clear)
                    }
                }

                if state.currentCouple == nil {
                    Section {
                        PairingCardView(showsShadow: false) {
                            showPairingSheet = true
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                }

                Section("Couple Details") {
                    TextField("Your Display Name", text: $displayName)
                    DatePicker("Anniversary", selection: $anniversary, displayedComponents: .date)
                    
                    Button {
                        Task {
                            isSaving = true
                            try? await SupabaseManager.shared.updateProfileDetails(name: displayName, anniversary: anniversary)
                            await state.initializeApp() // Refresh state
                            isSaving = false
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text("Save Details")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(displayName.isEmpty)
                }

                Section("Preferences") {
                    Picker("Distance Unit", selection: $distanceUnit) {
                        ForEach(DistanceUnitOption.allCases, id: \.rawValue) { option in
                            Text(option.label).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("About") {
                    Link("Terms of Service", destination: URL(string: "https://apple.com")!)
                    Link("Privacy Policy", destination: URL(string: "https://apple.com")!)
                }

                Section("Account Management") {
                    Button("Sign Out") {
                        Task {
                            try? await SupabaseManager.shared.signOut()
                            await state.initializeApp()
                        }
                    }
                    .foregroundStyle(.red)
                }

                Section("Danger Zone") {
                    Button(role: .destructive) {
                        isShowingUnpairAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "heart.slash.fill")
                            Text("Unpair from Partner")
                        }
                    }

                    Button("DEV: Force Reset & Sign Out", role: .destructive) {
                        Task {
                            // 1. Wipe the secure iOS Keychain
                            try? await SupabaseManager.shared.signOut()

                            // 2. Reset the Onboarding router
                            hasCompletedOnboarding = false

                            // 3. Clear the local UI state so ContentView updates instantly
                            state.currentUser = nil
                            state.currentCouple = nil
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Unpair from Partner?", isPresented: $isShowingUnpairAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Unpair", role: .destructive) {
                    Task {
                        await state.unpair()
                    }
                }
            } message: {
                Text("This will permanently sever your connection. All shared memories, map pins, and drawings will be deleted for both of you. This cannot be undone.")
            }
            .onAppear {
                if let name = state.currentUser?.displayName { displayName = name }
                if let date = state.currentUser?.anniversaryDate { anniversary = date }
                if distanceUnit != normalizedDistanceUnit {
                    distanceUnit = normalizedDistanceUnit
                }
                syncDistanceUnitToWidgetDefaults()
            }
            .onChange(of: distanceUnit) { _, _ in
                if distanceUnit != normalizedDistanceUnit {
                    distanceUnit = normalizedDistanceUnit
                }
                syncDistanceUnitToWidgetDefaults()
            }
            .confirmationDialog("Profile Photo", isPresented: $showPhotoOptions, titleVisibility: .visible) {
                Button("Take Photo") { showCamera = true }
                Button("Choose from Library") { showPhotoLibrary = true }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showCamera) {
                CameraImagePicker(source: .camera) { image in
                    Task { await uploadAvatar(image) }
                }
            }
            .sheet(isPresented: $showPhotoLibrary) {
                CameraImagePicker(source: .photoLibrary) { image in
                    Task { await uploadAvatar(image) }
                }
            }
            .fullScreenCover(isPresented: $showPairingSheet) {
                PairingView()
                    .environment(state)
            }
        }
    }

    /// Uploads the picked photo and refreshes widget avatars.
    private func uploadAvatar(_ image: UIImage) async {
        isUploadingAvatar = true
        avatarError = nil
        defer { isUploadingAvatar = false }
        do {
            try await state.uploadProfileAvatar(image)
        } catch {
            avatarError = error.localizedDescription
        }
    }
}

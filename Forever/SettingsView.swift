import SwiftUI
import StoreKit
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
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    private var ambientData = AmbientDataManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var displayName = ""
    @State private var partnerNickname = ""
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
    @State private var showCustomerCenter = false
    @State private var unavailableActionAlert: String?
    @State private var notificationStatusLabel = "Not Set"
    @State private var saveDetailsError: String?
    @State private var coupleDetailsSaveTask: Task<Void, Never>?

    private var normalizedDistanceUnit: String {
        DistanceUnitOption(rawValue: distanceUnit)?.rawValue ?? DistanceUnitOption.miles.rawValue
    }

    private var hasProfilePhoto: Bool {
        state.myAvatarImage != nil || state.currentUser?.avatarUrl != nil
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
                            .font(ForeverFont.caption())
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

                Section {
                    TextField("Your Display Name", text: $displayName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            saveCoupleDetailsIfNeeded()
                        }
                    TextField("Partner's Display Name", text: $partnerNickname)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            saveCoupleDetailsIfNeeded()
                        }
                    DatePicker("Anniversary", selection: $anniversary, displayedComponents: .date)
                        .onChange(of: anniversary) { _, _ in
                            saveCoupleDetailsIfNeeded()
                        }

                    if isSaving {
                        HStack {
                            Spacer()
                            ProgressView()
                            Text("Saving...")
                                .font(ForeverFont.caption())
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                } header: {
                    Text("Couple Details")
                }

                Section("Preferences") {
                    Picker("Distance Unit", selection: $distanceUnit) {
                        ForEach(DistanceUnitOption.allCases, id: \.rawValue) { option in
                            Text(option.label).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Permissions") {
                    Button {
                        Task {
                            await NotificationAuthorizationManager.handlePermissionTap()
                            await refreshNotificationStatusLabel()
                        }
                    } label: {
                        settingsActionRow(
                            title: "Notifications",
                            status: notificationStatusLabel
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        ambientData.handleLocationPermissionTap()
                    } label: {
                        settingsActionRow(
                            title: "Location Permission",
                            status: ambientData.locationPermissionStatusLabel
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section("Library") {
                    NavigationLink {
                        ArchiveView(embedded: true)
                    } label: {
                        Text("Drawing Archive")
                    }
                }

                Section("App") {
                    settingsLinkRow(title: "Manage Subscription") {
                        showCustomerCenter = true
                    }

                    settingsLinkRow(title: "Rate the App") {
                        requestReview()
                    }
                }

                Section("Support") {
                    settingsLinkRow(
                        title: "Contact Support",
                        isEnabled: AppSupportConfiguration.contactSupportURL != nil
                    ) {
                        openConfiguredURL(AppSupportConfiguration.contactSupportURL, actionName: "Contact Support")
                    }

                    settingsLinkRow(
                        title: "Share Feedback",
                        isEnabled: AppSupportConfiguration.feedbackMailtoURL != nil
                    ) {
                        openConfiguredURL(AppSupportConfiguration.feedbackMailtoURL, actionName: "Share Feedback")
                    }
                }

                Section("Legal") {
                    settingsLinkRow(
                        title: "Terms of Service",
                        isEnabled: AppSupportConfiguration.termsOfServiceURL != nil
                    ) {
                        openConfiguredURL(AppSupportConfiguration.termsOfServiceURL, actionName: "Terms of Service")
                    }

                    settingsLinkRow(
                        title: "Privacy Policy",
                        isEnabled: AppSupportConfiguration.privacyPolicyURL != nil
                    ) {
                        openConfiguredURL(AppSupportConfiguration.privacyPolicyURL, actionName: "Privacy Policy")
                    }
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
                syncCoupleDetailsFromProfile()
                if distanceUnit != normalizedDistanceUnit {
                    distanceUnit = normalizedDistanceUnit
                }
                syncDistanceUnitToWidgetDefaults()
                Task { await refreshNotificationStatusLabel() }
            }
            .onDisappear {
                saveCoupleDetailsIfNeeded()
            }
            .onChange(of: state.currentUser?.displayName) { _, _ in
                guard !hasUnsavedCoupleDetails else { return }
                syncCoupleDetailsFromProfile()
            }
            .onChange(of: state.currentUser?.partnerNickname) { _, _ in
                guard !hasUnsavedCoupleDetails else { return }
                syncCoupleDetailsFromProfile()
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
                if hasProfilePhoto {
                    Button("Remove Photo", role: .destructive) {
                        Task { await removeAvatar() }
                    }
                }
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
                PairingView(usesInviteEntryLayout: false)
                    .environment(state)
            }
            .foreverCustomerCenter(isPresented: $showCustomerCenter)
            .alert("Not Available", isPresented: Binding(
                get: { unavailableActionAlert != nil },
                set: { if !$0 { unavailableActionAlert = nil } }
            )) {
                Button("OK", role: .cancel) { unavailableActionAlert = nil }
            } message: {
                Text(unavailableActionAlert ?? "")
            }
            .alert("Could Not Save", isPresented: Binding(
                get: { saveDetailsError != nil },
                set: { if !$0 { saveDetailsError = nil } }
            )) {
                Button("OK", role: .cancel) { saveDetailsError = nil }
            } message: {
                Text(saveDetailsError ?? "")
            }
        }
    }

    /// Loads couple details from the signed-in profile when there are no local edits.
    private func syncCoupleDetailsFromProfile() {
        if let name = state.currentUser?.displayName {
            displayName = name
        }
        partnerNickname = state.currentUser?.partnerNickname ?? ""
        if let date = state.currentUser?.anniversaryDate {
            anniversary = date
        }
    }

    /// Whether the couple details fields differ from what is stored on the profile.
    private var hasUnsavedCoupleDetails: Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }

        let savedName = (state.currentUser?.displayName ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName != savedName {
            return true
        }

        let trimmedPartnerNickname = partnerNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedPartnerNickname = (state.currentUser?.partnerNickname ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPartnerNickname != savedPartnerNickname {
            return true
        }

        guard let savedAnniversary = state.currentUser?.anniversaryDate else {
            return true
        }
        return !Calendar.current.isDate(savedAnniversary, inSameDayAs: anniversary)
    }

    /// Saves couple details when they changed; coalesces rapid triggers.
    private func saveCoupleDetailsIfNeeded() {
        guard hasUnsavedCoupleDetails, !isSaving else { return }
        coupleDetailsSaveTask?.cancel()
        coupleDetailsSaveTask = Task {
            await saveCoupleDetails()
        }
    }

    /// Persists display name and anniversary to Supabase and refreshes local state.
    private func saveCoupleDetails() async {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, hasUnsavedCoupleDetails else { return }
        guard !isSaving else { return }

        let trimmedPartnerNickname = partnerNickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let nicknameToSave = trimmedPartnerNickname.isEmpty ? nil : trimmedPartnerNickname

        isSaving = true
        saveDetailsError = nil
        defer { isSaving = false }

        do {
            try await state.updateProfileDetails(
                name: trimmedName,
                partnerNickname: nicknameToSave,
                anniversary: anniversary
            )
            displayName = trimmedName
            partnerNickname = trimmedPartnerNickname
        } catch {
            if !Task.isCancelled {
                saveDetailsError = error.localizedDescription
            }
        }
    }

    /// Shared text-only row layout for Me tab action rows.
    private func settingsActionRow(
        title: String,
        status: String? = nil,
        titleColor: Color? = nil
    ) -> some View {
        HStack {
            Group {
                if let titleColor {
                    Text(title).foregroundStyle(titleColor)
                } else {
                    Text(title)
                }
            }
            Spacer()
            if let status {
                Text(status)
                    .font(ForeverFont.caption())
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    /// Wraps an action row with consistent enabled/disabled styling.
    private func settingsLinkRow(
        title: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            settingsActionRow(title: title)
        }
        .disabled(!isEnabled)
        .foregroundStyle(isEnabled ? .primary : .tertiary)
    }

    /// Opens a configured URL or shows a gentle alert when not yet available.
    private func openConfiguredURL(_ url: URL?, actionName: String) {
        guard let url else {
            unavailableActionAlert = "\(actionName) will be available soon."
            return
        }
        openURL(url)
    }

    /// Refreshes the notification permission status shown in the Me tab.
    private func refreshNotificationStatusLabel() async {
        notificationStatusLabel = await NotificationAuthorizationManager.permissionStatusLabel()
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

    /// Removes the profile photo and refreshes widget avatars.
    private func removeAvatar() async {
        isUploadingAvatar = true
        avatarError = nil
        defer { isUploadingAvatar = false }
        do {
            try await state.removeProfileAvatar()
        } catch {
            avatarError = error.localizedDescription
        }
    }
}

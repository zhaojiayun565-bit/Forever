import CoreLocation
import Foundation
import Kingfisher
import Observation
import UIKit
import WidgetKit
import Supabase
import SwiftData

/// Coordinate for map focus after saving a memory; explicit `Equatable` for SwiftUI `onChange`.
struct NewlyAddedMemoryCoordinate: Equatable {
    let latitude: Double
    let longitude: Double
}

/// First memory captured during onboarding; uploaded after Apple Sign-In.
struct PendingOnboardingMemory: Codable, Equatable {
    let imageFileName: String
    let note: String
    let latitude: Double
    let longitude: Double
    let createdAt: Date
}

/// App-wide session, profile, and pairing state.
@MainActor
@Observable
final class AppStateManager {
    let supabase: SupabaseManager

    var currentUser: Profile?
    var currentCouple: Couple?
    var partnerProfile: Profile?
    /// Locally cached profile photo (App Group file); kept in sync after pick/upload.
    var myAvatarImage: UIImage?
    var memories: [CoupleMemory] = []
    /// Set after saving a memory so the map can animate to it; cleared by the map after handling.
    var newlyAddedLocation: NewlyAddedMemoryCoordinate?
    var isLoading = true
    let realtime: RealtimeListenerRegistry

    init(supabase: SupabaseManager = .shared) {
        self.supabase = supabase
        self.realtime = RealtimeListenerRegistry(supabase: supabase)
    }

    /// Ensures auth, profile (with a random 6-digit code if new), and couple state are loaded.
    func initializeApp() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // 1. Check if user is actually logged in
            if let session = await supabase.getSession() {
                await SubscriptionManager.shared.syncUserID(session.user.id.uuidString)
                // 2. Fetch or create their database profile
                var profile = try await supabase.fetchProfile()
                if profile == nil {
                    print("👤 Creating new profile for authenticated user...")
                    try await Self.createProfileWithRetries(supabase: supabase)
                    profile = try await supabase.fetchProfile()
                }

                currentUser = profile
                try? await supabase.updateTimezone(TimeZone.current.identifier)
                loadMyAvatarFromAppGroup()
                currentCouple = try await supabase.fetchCurrentCouple()
                AmbientDataManager.shared.resetUploadThrottle()
                if currentCouple != nil {
                    // Paired: upload our location now (a cold launch never triggers the
                    // scenePhase `.active` handler), then refresh partner + widgets.
                    startCoupleListeners()
                    await syncAndRefreshWidgets()
                } else {
                    syncMyWidgetDefaults()
                    startCoupleLinkListener()
                }
                await applyOnboardingDraftIfNeeded()
                await SubscriptionManager.shared.refreshSharedPremiumAccess(appState: self)
                await flushPendingDeviceToken()
                print("✅ SUCCESS: Profile loaded.")
            } else {
                await SubscriptionManager.shared.syncUserID(nil)
                // Not logged in. Clear state so LoginView shows.
                await realtime.stopAll()
                currentUser = nil
                currentCouple = nil
                partnerProfile = nil
                myAvatarImage = nil
                clearWidgetData(includePersonalData: true)
                WidgetCenter.shared.reloadAllTimelines()
                print("🔒 User is not authenticated. Awaiting login.")
            }
        } catch {
            print("🚨 INIT ERROR: \(error)")
            await realtime.stopAll()
            currentUser = nil
            currentCouple = nil
            partnerProfile = nil
            myAvatarImage = nil
            clearWidgetData(includePersonalData: true)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Loads the signed-in user's avatar from the App Group cache.
    private func loadMyAvatarFromAppGroup() {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.suiteName) else { return }
        let fileURL = container.appendingPathComponent(AppGroup.myAvatarFileName)
        guard let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) else { return }
        myAvatarImage = image
    }

    /// Re-fetches the canonical couple row (e.g. after questions streak updates).
    func refreshCurrentCouple() async {
        if let couple = try? await supabase.fetchCurrentCouple() {
            currentCouple = couple
        }
    }

    /// How the signed-in user sees their partner (nickname override, then partner profile name).
    var partnerDisplayName: String {
        let nickname = currentUser?.partnerNickname?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let nickname, !nickname.isEmpty { return nickname }
        return partnerProfile?.displayName ?? "Partner"
    }

    /// Saves display name, partner nickname, and anniversary; refreshes local state and widgets.
    func updateProfileDetails(name: String, partnerNickname: String?, anniversary: Date) async throws {
        try await supabase.updateProfileDetails(
            name: name,
            partnerNickname: partnerNickname,
            anniversary: anniversary
        )
        guard let updated = try await supabase.fetchProfile() else { return }
        currentUser = updated
        if let partner = partnerProfile {
            updateWidgetData(partner: partner)
        } else {
            syncMyWidgetDefaults()
        }
    }

    /// Uploads our location to Supabase, refreshes currentUser so its lat/lon is current,
    /// then fetches the partner's profile and reloads widget data.
    func syncAndRefreshWidgets() async {
        do {
            if try await AmbientDataManager.shared.syncData(),
               let updated = try? await supabase.fetchProfile() {
                currentUser = updated
            }
        } catch {
            print("🚨 Location sync error: \(error)")
        }
        await loadPartnerProfile()
    }

    /// Fetches the partner's profile and updates the widget data
    func loadPartnerProfile() async {
        guard let couple = currentCouple, let myId = currentUser?.id else { return }
        // Determine which ID is the partner
        let partnerId = couple.user1Id == myId ? couple.user2Id : couple.user1Id

        do {
            let partner: Profile = try await supabase.client
                .from("profiles")
                .select()
                .eq("id", value: partnerId)
                .single()
                .execute()
                .value

            self.partnerProfile = partner
            self.updateWidgetData(partner: partner)
            await syncAvatarImagesToAppGroup()
        } catch {
            print("🚨 Failed to fetch partner profile: \(error)")
        }
    }

    func loadMemories() async {
        guard let user = currentUser else { return }
        do {
            memories = try await supabase.fetchMemories(coupleId: currentCouple?.id, creatorId: user.id)
        } catch {
            print("🚨 Fetch Memories Error: \(error)")
        }
    }

    /// Stages the onboarding first memory locally until the user signs in with Apple.
    func stageOnboardingMemory(image: UIImage, note: String, coordinate: CLLocationCoordinate2D) throws {
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(
                domain: "OnboardingMemory",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Could not process the photo."]
            )
        }
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.suiteName) else {
            throw NSError(
                domain: "OnboardingMemory",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Storage unavailable."]
            )
        }

        let fileName = AppGroup.pendingOnboardingMemoryFileName
        let fileURL = container.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)

        let pending = PendingOnboardingMemory(
            imageFileName: fileName,
            note: note,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            createdAt: Date()
        )
        persistPendingOnboardingMemory(pending)
    }

    /// Whether a staged onboarding memory is waiting in the App Group.
    var hasPendingOnboardingMemory: Bool {
        loadPendingOnboardingMemory() != nil
    }

    /// Uploads a staged onboarding memory from App Group storage after authentication.
    @discardableResult
    func flushPendingOnboardingMemory() async -> Bool {
        guard let pending = loadPendingOnboardingMemory(), currentUser != nil else { return false }
        guard let image = loadPendingOnboardingImage(pending) else {
            clearPendingOnboardingMemory()
            return false
        }

        let coordinate = CLLocationCoordinate2D(latitude: pending.latitude, longitude: pending.longitude)
        do {
            try await saveMemory(
                images: [image],
                note: pending.note,
                coordinate: coordinate,
                date: pending.createdAt
            )
            clearPendingOnboardingMemory()
            return true
        } catch {
            print("🚨 Flush onboarding memory error: \(error)")
            return false
        }
    }

    /// Uploads onboarding answers captured before sign-in (names, anniversary, first memory).
    /// Each part is cleared only after it saves, so failures retry on the next launch / sign-in.
    func applyOnboardingDraftIfNeeded() async {
        guard let user = currentUser else { return }

        let draft = OnboardingFlowStorage.loadDraft()
        if draft.hasProfileDetails, let anniversary = draft.anniversary ?? user.anniversaryDate {
            let name = draft.trimmedMyName.isEmpty ? (user.displayName ?? "") : draft.trimmedMyName
            let nickname = draft.trimmedPartnerName.isEmpty ? user.partnerNickname : draft.trimmedPartnerName
            do {
                try await updateProfileDetails(name: name, partnerNickname: nickname, anniversary: anniversary)
                OnboardingFlowStorage.clearDraft()
            } catch {
                print("🚨 Apply onboarding draft error: \(error)")
            }
        }

        if hasPendingOnboardingMemory {
            await flushPendingOnboardingMemory()
        }
    }

    /// Uploads images and inserts a memory row (solo or coupled).
    func saveMemory(
        images: [UIImage],
        note: String,
        coordinate: CLLocationCoordinate2D,
        date: Date = Date()
    ) async throws {
        guard let creatorId = currentUser?.id else {
            throw NSError(
                domain: "Memory",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Authentication error. Please log in again."]
            )
        }

        let coupleIdForMemory = currentCouple?.id
        let uploadedUrls = try await withThrowingTaskGroup(of: URL.self) { group in
            for image in images {
                if let data = image.jpegData(compressionQuality: 0.7) {
                    group.addTask {
                        try await self.supabase.uploadMemoryImage(
                            data: data,
                            coupleId: coupleIdForMemory,
                            creatorId: creatorId
                        )
                    }
                }
            }

            var urls: [URL] = []
            for try await url in group {
                urls.append(url)
            }
            return urls
        }

        guard !uploadedUrls.isEmpty else {
            throw NSError(
                domain: "Memory",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to process images. Please try again."]
            )
        }

        try await supabase.insertMemory(
            coupleId: coupleIdForMemory,
            creatorId: creatorId,
            imageUrls: uploadedUrls,
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            date: date,
            note: note
        )
        await loadMemories()
        newlyAddedLocation = NewlyAddedMemoryCoordinate(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    private func persistPendingOnboardingMemory(_ pending: PendingOnboardingMemory) {
        guard let defaults = UserDefaults(suiteName: AppGroup.suiteName),
              let data = try? JSONEncoder().encode(pending) else { return }
        defaults.set(data, forKey: AppGroup.pendingOnboardingMemoryMetadataKey)
    }

    private func loadPendingOnboardingMemory() -> PendingOnboardingMemory? {
        guard let defaults = UserDefaults(suiteName: AppGroup.suiteName),
              let data = defaults.data(forKey: AppGroup.pendingOnboardingMemoryMetadataKey) else { return nil }
        return try? JSONDecoder().decode(PendingOnboardingMemory.self, from: data)
    }

    private func loadPendingOnboardingImage(_ pending: PendingOnboardingMemory) -> UIImage? {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.suiteName) else {
            return nil
        }
        let fileURL = container.appendingPathComponent(pending.imageFileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    private func clearPendingOnboardingMemory() {
        if let defaults = UserDefaults(suiteName: AppGroup.suiteName) {
            defaults.removeObject(forKey: AppGroup.pendingOnboardingMemoryMetadataKey)
        }
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.suiteName) {
            let fileURL = container.appendingPathComponent(AppGroup.pendingOnboardingMemoryFileName)
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Pushes partner + self fields to the App Group and reloads only the widgets whose data changed.
    private func updateWidgetData(partner: Profile) {
        guard var writer = WidgetDefaultsWriter() else { return }

        let myCoordinate = currentUser?.coordinate
        let partnerCoordinate = partner.coordinate
        writer.setCoordinate(myCoordinate, latitudeKey: WidgetDefaultsKey.myLatitude, longitudeKey: WidgetDefaultsKey.myLongitude)
        writer.setCoordinate(partnerCoordinate, latitudeKey: WidgetDefaultsKey.partnerLatitude, longitudeKey: WidgetDefaultsKey.partnerLongitude)
        if let myCoordinate, let partnerCoordinate {
            let miles = CLLocation(latitude: myCoordinate.latitude, longitude: myCoordinate.longitude)
                .distance(from: CLLocation(latitude: partnerCoordinate.latitude, longitude: partnerCoordinate.longitude)) / 1609.344
            writer.set((miles * 100).rounded() / 100, forKey: WidgetDefaultsKey.partnerDistance, affects: WidgetKind.distance)
        }
        writer.set(
            partner.locationUpdatedAt?.timeIntervalSince1970,
            forKey: WidgetDefaultsKey.partnerLocationUpdatedAt,
            affects: WidgetKind.distance
        )
        writer.set(
            UserDefaults.standard.string(forKey: "distanceUnit") ?? "mi",
            forKey: "distanceUnit",
            affects: WidgetKind.distance
        )

        writer.set(partner.latestNoteUrl, forKey: WidgetDefaultsKey.partnerNoteUrl, affects: [WidgetKind.drawing])
        writer.set(partnerDisplayName, forKey: "partnerName", affects: WidgetKind.all)
        writer.set(partner.latestMessage, forKey: WidgetDefaultsKey.partnerMessage, affects: [WidgetKind.lockScreenMessage, WidgetKind.distanceHome])
        writer.set(currentUser?.latestMessage, forKey: "myMessage", affects: [WidgetKind.distanceHome])
        writer.set(
            (currentUser?.anniversaryDate ?? partner.anniversaryDate)?.timeIntervalSince1970,
            forKey: "anniversaryDate",
            affects: [WidgetKind.daysTogether]
        )
        writer.set(partner.avatarUrl, forKey: "partnerAvatarUrl", affects: [WidgetKind.distanceHome, WidgetKind.daysTogether])
        writeMyWidgetFields(into: &writer)
        writer.reload()
    }

    /// Persists the signed-in user's name, avatar, and anniversary to widget defaults when unpaired.
    private func syncMyWidgetDefaults() {
        guard var writer = WidgetDefaultsWriter() else { return }
        writeMyWidgetFields(into: &writer)
        if let date = currentUser?.anniversaryDate {
            writer.set(date.timeIntervalSince1970, forKey: "anniversaryDate", affects: [WidgetKind.daysTogether])
        }
        writer.reload()
    }

    /// Writes fields owned by the signed-in user (name, avatar URL).
    private func writeMyWidgetFields(into writer: inout WidgetDefaultsWriter) {
        if let myName = currentUser?.displayName {
            writer.set(myName, forKey: "myName", affects: WidgetKind.all)
        }
        writer.set(currentUser?.avatarUrl, forKey: "myAvatarUrl", affects: [WidgetKind.distanceHome, WidgetKind.daysTogether])
    }

    /// Downloads avatar images into the App Group (only when the URL changed) so widgets render them offline.
    func syncAvatarImagesToAppGroup() async {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.suiteName),
              var writer = WidgetDefaultsWriter() else { return }

        let avatars: [(url: String?, fileName: String, cacheKey: String)] = [
            (currentUser?.avatarUrl, AppGroup.myAvatarFileName, "myAvatarCachedUrl"),
            (partnerProfile?.avatarUrl, AppGroup.partnerAvatarFileName, "partnerAvatarCachedUrl")
        ]
        for avatar in avatars {
            let fileURL = container.appendingPathComponent(avatar.fileName)
            guard let urlString = avatar.url, let url = URL(string: urlString) else { continue }
            let isCached = writer.defaults.string(forKey: avatar.cacheKey) == urlString
                && FileManager.default.fileExists(atPath: fileURL.path)
            guard !isCached, let data = try? await URLSession.shared.data(from: url).0 else { continue }
            try? data.write(to: fileURL, options: .atomic)
            writer.set(urlString, forKey: avatar.cacheKey, affects: [WidgetKind.distanceHome, WidgetKind.daysTogether])
        }
        writer.reload()
    }

    /// Saves a freshly picked avatar locally and uploads it to Supabase.
    func uploadProfileAvatar(_ image: UIImage) async throws {
        guard let data = image.resizedForAvatar()?.jpegData(compressionQuality: 0.85) else { return }

        myAvatarImage = image
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.suiteName) {
            try data.write(to: container.appendingPathComponent(AppGroup.myAvatarFileName), options: .atomic)
        }

        if let urlString = currentUser?.avatarUrl, let url = URL(string: urlString) {
            try? await ImageCache.default.removeImage(forKey: url.absoluteString)
        }

        _ = try await supabase.uploadProfileAvatar(data)
        if let updated = try? await supabase.fetchProfile() {
            currentUser = updated
            if let urlString = updated.avatarUrl, let url = URL(string: urlString) {
                try? await ImageCache.default.removeImage(forKey: url.absoluteString)
            }
        }
        if let partner = partnerProfile {
            updateWidgetData(partner: partner)
        }
        markAvatarWidgetsChanged(cachedURL: currentUser?.avatarUrl)
    }

    /// Records the avatar URL now cached on disk and reloads widgets that show avatars.
    private func markAvatarWidgetsChanged(cachedURL: String?) {
        guard var writer = WidgetDefaultsWriter() else { return }
        writer.set(cachedURL, forKey: "myAvatarCachedUrl", affects: [])
        writer.markChanged([WidgetKind.distanceHome, WidgetKind.daysTogether])
        writer.reload()
    }

    /// Clears the signed-in user's avatar locally and in Supabase.
    func removeProfileAvatar() async throws {
        if let urlString = currentUser?.avatarUrl, let url = URL(string: urlString) {
            try? await ImageCache.default.removeImage(forKey: url.absoluteString)
        }

        try await supabase.removeProfileAvatar()

        myAvatarImage = nil
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.suiteName) {
            try? FileManager.default.removeItem(at: container.appendingPathComponent(AppGroup.myAvatarFileName))
        }

        if let updated = try? await supabase.fetchProfile() {
            currentUser = updated
        }
        if let partner = partnerProfile {
            updateWidgetData(partner: partner)
        }
        markAvatarWidgetsChanged(cachedURL: nil)
    }

    /// After the user enters a partner code, links accounts and refreshes `currentCouple`.
    func linkWithPartner(code: String) async throws {
        let newlyFetchedCouple = try await supabase.linkPartner(code: code)
        guard let user = currentUser else { return }
        try await supabase.attachSoloMemoriesToCouple(coupleId: newlyFetchedCouple.id, creatorId: user.id)
        await didPair(with: newlyFetchedCouple)
    }

    /// Shared setup once a couple exists (we entered a code, or the partner entered ours).
    func didPair(with couple: Couple) async {
        currentCouple = couple
        startCoupleListeners()
        AmbientDataManager.shared.resetUploadThrottle()
        await syncAndRefreshWidgets()
        await loadMemories()
        await SubscriptionManager.shared.refreshSharedPremiumAccess(appState: self)
    }

    /// Tears down the couple server-side, then clears local + widget state.
    func unpair() async {
        guard currentCouple != nil else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Atomically delete the couple, its memories, and drawings server-side first.
            try await supabase.unpairCouple()

            await resetCoupleState()
        } catch {
            print("🚨 Failed to unpair: \(error)")
        }
    }

    /// Clears every local trace of a deleted account and routes back to the start of onboarding.
    func handleAccountDeleted() async {
        if let cachedTexts = try? SharedDatabase.context.fetch(FetchDescriptor<CherishedText>()) {
            cachedTexts.forEach { SharedDatabase.context.delete($0) }
            try? SharedDatabase.context.save()
        }

        let localFlags = ["hasCompletedOnboarding", "hasSkippedPairing"] + OnboardingFlowStorage.allKeys
        localFlags.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        clearPendingOnboardingMemory()

        memories.removeAll()
        await initializeApp()
    }

    /// Wipes partner-derived values from the App Group so widgets can't show stale data after unpairing.
    func clearPartnerWidgetData() {
        clearWidgetData(includePersonalData: false)
    }

    /// Clears cached widget data; optionally removes the signed-in user's cached location too.
    private func clearWidgetData(includePersonalData: Bool) {
        guard let defaults = UserDefaults(suiteName: "group.com.jiayunzhao.Forever") else { return }
        let partnerKeys = [
            "partnerBattery",
            "partnerDistance",
            "partnerLatitude",
            "partnerLongitude",
            "partnerLocationUpdatedAt",
            "partnerNoteUrl",
            "partnerName",
            "partnerMessage",
            "myMessage",
            "partnerAvatarUrl",
            "partnerAvatarCachedUrl",
            "anniversaryDate"
        ]
        partnerKeys.forEach { defaults.removeObject(forKey: $0) }

        if includePersonalData {
            let personalKeys = [
                "myLatitude",
                "myLongitude",
                "myName",
                "myMessage",
                "myAvatarUrl",
                "myAvatarCachedUrl"
            ]
            personalKeys.forEach { defaults.removeObject(forKey: $0) }
        }

        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.suiteName) {
            try? FileManager.default.removeItem(at: container.appendingPathComponent(AppGroup.partnerAvatarFileName))
            if includePersonalData {
                try? FileManager.default.removeItem(at: container.appendingPathComponent(AppGroup.myAvatarFileName))
            }
        }
    }

    /// Attaches a device token cached before sign-in to the now-authenticated user.
    private func flushPendingDeviceToken() async {
        guard let defaults = UserDefaults(suiteName: AppGroup.suiteName),
              let token = defaults.string(forKey: AppGroup.pendingDeviceTokenKey)
        else { return }
        try? await supabase.updateDeviceToken(token)
    }

    private static func randomSixDigitCode() -> String {
        String(format: "%06d", Int.random(in: 0 ... 999_999))
    }

    /// Retries on unique `pairing_code` collisions.
    private static func createProfileWithRetries(supabase: SupabaseManager) async throws {
        for _ in 0 ..< 10 {
            do {
                try await supabase.createProfile(code: randomSixDigitCode())
                return
            } catch {
                continue
            }
        }
        try await supabase.createProfile(code: randomSixDigitCode())
    }
}

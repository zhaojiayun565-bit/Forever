import CoreLocation
import Foundation
import Kingfisher
import Observation
import UIKit
import WidgetKit
import Supabase

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
    private let supabase: SupabaseManager

    var currentUser: Profile?
    var currentCouple: Couple?
    var partnerProfile: Profile?
    /// Locally cached profile photo (App Group file); kept in sync after pick/upload.
    var myAvatarImage: UIImage?
    var memories: [CoupleMemory] = []
    /// Set after saving a memory so the map can animate to it; cleared by the map after handling.
    var newlyAddedLocation: NewlyAddedMemoryCoordinate?
    var isLoading = true
    private var pairingListenerTask: Task<Void, Never>?
    private var partnerLocationListenerTask: Task<Void, Never>?
    private var memoriesListenerTask: Task<Void, Never>?

    init(supabase: SupabaseManager = .shared) {
        self.supabase = supabase
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
                loadMyAvatarFromAppGroup()
                currentCouple = try await supabase.fetchCurrentCouple()
                if currentCouple != nil {
                    // Paired: upload our location now (a cold launch never triggers the
                    // scenePhase `.active` handler), then refresh partner + widgets and
                    // start listening for the partner's live profile changes.
                    await syncAndRefreshWidgets()
                    subscribeToPartnerProfile()
                    subscribeToMemories()
                } else {
                    await loadPartnerProfile()
                    subscribeToCoupleLink()
                }
                await SubscriptionManager.shared.refreshSharedPremiumAccess(appState: self)
                await flushPendingDeviceToken()
                print("✅ SUCCESS: Profile loaded.")
            } else {
                await SubscriptionManager.shared.syncUserID(nil)
                // Not logged in. Clear state so LoginView shows.
                cancelRealtimeListeners()
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
            cancelRealtimeListeners()
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

    /// Stops all Realtime listener tasks (sign-out, unpair, or auth failure).
    private func cancelRealtimeListeners() {
        pairingListenerTask?.cancel()
        pairingListenerTask = nil
        partnerLocationListenerTask?.cancel()
        partnerLocationListenerTask = nil
        memoriesListenerTask?.cancel()
        memoriesListenerTask = nil
    }

    /// Uploads our location to Supabase, refreshes currentUser so its lat/lon is current,
    /// then fetches the partner's profile and reloads widget data.
    func syncAndRefreshWidgets() async {
        do {
            try await AmbientDataManager.shared.syncData()
            if let updated = try? await supabase.fetchProfile() {
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

    /// Uploads an in-memory onboarding capture when App Group pending data is unavailable.
    @discardableResult
    func flushOnboardingMemory(
        image: UIImage,
        note: String,
        coordinate: CLLocationCoordinate2D,
        createdAt: Date = Date()
    ) async -> Bool {
        guard currentUser != nil else { return false }
        do {
            try await saveMemory(
                images: [image],
                note: note,
                coordinate: coordinate,
                date: createdAt
            )
            clearPendingOnboardingMemory()
            return true
        } catch {
            print("🚨 Flush onboarding memory error: \(error)")
            return false
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

    /// Pushes partner fields to the App Group UserDefaults and reloads widgets only when values change.
    private func updateWidgetData(partner: Profile) {
        guard let defaults = UserDefaults(suiteName: "group.com.jiayunzhao.Forever") else { return }

        var didChange = false

        // 1. Battery
        if let battery = partner.batteryLevel {
            let key = "partnerBattery"
            let existing = defaults.object(forKey: key) as? Int
            if existing != battery {
                defaults.set(battery, forKey: key)
                didChange = true
            }
        }

        // 2. Distance + raw coordinates for the map widget
        if let myLat = currentUser?.latitude, let myLon = currentUser?.longitude,
           let pLat = partner.latitude, let pLon = partner.longitude {
            let myLocation = CLLocation(latitude: myLat, longitude: myLon)
            let partnerLocation = CLLocation(latitude: pLat, longitude: pLon)
            let distanceInMeters = myLocation.distance(from: partnerLocation)
            let distanceInMiles = distanceInMeters / 1609.344

            let key = "partnerDistance"
            let existing = defaults.object(forKey: key) as? Double
            let epsilonMiles = 0.0005
            let distanceChanged = existing.map { abs($0 - distanceInMiles) > epsilonMiles } ?? true
            if distanceChanged {
                defaults.set(distanceInMiles, forKey: key)
                didChange = true
            }

            // Explicit coordinate keys read by the distance map widget
            defaults.set(myLat, forKey: "myLatitude")
            defaults.set(myLon, forKey: "myLongitude")
            defaults.set(pLat, forKey: "partnerLatitude")
            defaults.set(pLon, forKey: "partnerLongitude")
            defaults.set(Date().timeIntervalSince1970, forKey: "partnerLocationUpdatedAt")
            didChange = true
        }

        // 3. Note URL
        let noteKey = "partnerNoteUrl"
        if let noteUrl = partner.latestNoteUrl {
            if defaults.string(forKey: noteKey) != noteUrl {
                defaults.set(noteUrl, forKey: noteKey)
                didChange = true
            }
        } else if defaults.object(forKey: noteKey) != nil {
            defaults.removeObject(forKey: noteKey)
            didChange = true
        }

        // 4. Name
        if let name = partner.displayName {
            let key = "partnerName"
            if defaults.string(forKey: key) != name {
                defaults.set(name, forKey: key)
                didChange = true
            }
        }
        if let myName = currentUser?.displayName {
            defaults.set(myName, forKey: "myName")
        }
        let preferredDistanceUnit = UserDefaults.standard.string(forKey: "distanceUnit") ?? "mi"
        if defaults.string(forKey: "distanceUnit") != preferredDistanceUnit {
            defaults.set(preferredDistanceUnit, forKey: "distanceUnit")
            didChange = true
        }

        // 5. Lock screen messages
        if let msg = partner.latestMessage {
            let key = "partnerMessage"
            if defaults.string(forKey: key) != msg {
                defaults.set(msg, forKey: key)
                didChange = true
            }
        } else if defaults.object(forKey: "partnerMessage") != nil {
            defaults.removeObject(forKey: "partnerMessage")
            didChange = true
        }
        if let myMsg = currentUser?.latestMessage {
            let key = "myMessage"
            if defaults.string(forKey: key) != myMsg {
                defaults.set(myMsg, forKey: key)
                didChange = true
            }
        } else if defaults.object(forKey: "myMessage") != nil {
            defaults.removeObject(forKey: "myMessage")
            didChange = true
        }

        // 6. Anniversary (stored as epoch seconds)
        if let date = partner.anniversaryDate {
            let key = "anniversaryDate"
            let value = date.timeIntervalSince1970
            let existing = defaults.object(forKey: key) as? Double
            if existing != value {
                defaults.set(value, forKey: key)
                didChange = true
            }
        }

        // 7. Avatar URLs for widget photo loading
        syncAvatarURL(defaults: defaults, key: "myAvatarUrl", url: currentUser?.avatarUrl, didChange: &didChange)
        syncAvatarURL(defaults: defaults, key: "partnerAvatarUrl", url: partner.avatarUrl, didChange: &didChange)

        if didChange {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// Writes an avatar URL to the App Group when it changes.
    private func syncAvatarURL(defaults: UserDefaults, key: String, url: String?, didChange: inout Bool) {
        if let url {
            if defaults.string(forKey: key) != url {
                defaults.set(url, forKey: key)
                didChange = true
            }
        } else if defaults.object(forKey: key) != nil {
            defaults.removeObject(forKey: key)
            didChange = true
        }
    }

    /// Downloads avatar images into the App Group so widgets can render them offline.
    func syncAvatarImagesToAppGroup() async {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.suiteName) else { return }

        if let urlString = currentUser?.avatarUrl, let url = URL(string: urlString),
           let data = try? await URLSession.shared.data(from: url).0 {
            try? data.write(to: container.appendingPathComponent(AppGroup.myAvatarFileName), options: .atomic)
        }

        if let urlString = partnerProfile?.avatarUrl, let url = URL(string: urlString),
           let data = try? await URLSession.shared.data(from: url).0 {
            try? data.write(to: container.appendingPathComponent(AppGroup.partnerAvatarFileName), options: .atomic)
        }

        WidgetCenter.shared.reloadAllTimelines()
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
        await syncAvatarImagesToAppGroup()
    }

    /// After the user enters a partner code, links accounts and refreshes `currentCouple`.
    func linkWithPartner(code: String) async throws {
        pairingListenerTask?.cancel()
        pairingListenerTask = nil
        let newlyFetchedCouple = try await supabase.linkPartner(code: code)
        currentCouple = newlyFetchedCouple
        guard let user = currentUser else { return }
        try await supabase.attachSoloMemoriesToCouple(coupleId: newlyFetchedCouple.id, creatorId: user.id)
        await loadPartnerProfile()
        await loadMemories()
        subscribeToPartnerProfile()
        subscribeToMemories()
        await SubscriptionManager.shared.refreshSharedPremiumAccess(appState: self)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Tears down the couple server-side, then clears local + widget state.
    func unpair() async {
        guard currentCouple != nil else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Atomically delete the couple, its memories, and drawings server-side first.
            try await supabase.unpairCouple()

            // Reset local state so routing returns to pairing flow.
            cancelRealtimeListeners()
            currentCouple = nil
            partnerProfile = nil
            memories.removeAll()
            clearPartnerWidgetData()
            WidgetCenter.shared.reloadAllTimelines()
            subscribeToCoupleLink()
            await SubscriptionManager.shared.refreshSharedPremiumAccess(appState: self)
            OnboardingFlowStorage.clearInvitePairingEntryOnly()

            print("✅ Successfully unpaired. UI should now route to PairingView.")
        } catch {
            print("🚨 Failed to unpair: \(error)")
        }
    }

    /// Wipes partner-derived values from the App Group so widgets can't show stale data after unpairing.
    private func clearPartnerWidgetData() {
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
            "anniversaryDate"
        ]
        partnerKeys.forEach { defaults.removeObject(forKey: $0) }

        if includePersonalData {
            let personalKeys = [
                "myLatitude",
                "myLongitude",
                "myName",
                "myMessage",
                "myAvatarUrl"
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

    /// Subscribes to Realtime INSERT events on `couples` so the waiting partner's app
    /// transitions automatically when the other person enters their code.
    private func subscribeToCoupleLink() {
        guard let userId = currentUser?.id else { return }
        pairingListenerTask?.cancel()
        pairingListenerTask = Task {
            let channel = supabase.client.realtimeV2
                .channel("couple-link-\(userId)")
            let inserts = channel.postgresChange(
                InsertAction.self, schema: "public", table: "couples"
            )
            do {
                try await channel.subscribeWithError()
            } catch {
                print("🚨 Couple-link subscribe failed: \(error)")
            }
            defer { Task { await self.supabase.client.realtimeV2.removeChannel(channel) } }

            for await _ in inserts {
                guard !Task.isCancelled else { return }
                if let couple = try? await supabase.fetchCurrentCouple() {
                    currentCouple = couple
                    await loadPartnerProfile()
                    await loadMemories()
                    subscribeToPartnerProfile()
                    subscribeToMemories()
                    await SubscriptionManager.shared.refreshSharedPremiumAccess(appState: self)
                }
                return
            }
        }
    }

    /// Subscribes to Realtime INSERT/UPDATE/DELETE on `memories` so the map refreshes
    /// the moment either partner adds, edits, or removes a pin.
    private func subscribeToMemories() {
        guard let coupleId = currentCouple?.id else { return }

        memoriesListenerTask?.cancel()
        memoriesListenerTask = Task {
            let channel = supabase.client.realtimeV2
                .channel("couple-memories-\(coupleId)")
            let filter = "couple_id=eq.\(coupleId)"
            let inserts = channel.postgresChange(
                InsertAction.self, schema: "public", table: "memories", filter: filter
            )
            let updates = channel.postgresChange(
                UpdateAction.self, schema: "public", table: "memories", filter: filter
            )
            let deletes = channel.postgresChange(
                DeleteAction.self, schema: "public", table: "memories", filter: filter
            )
            do {
                try await channel.subscribeWithError()
            } catch {
                print("🚨 Memories subscribe failed: \(error)")
                return
            }
            defer { Task { await self.supabase.client.realtimeV2.removeChannel(channel) } }

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in inserts {
                        guard !Task.isCancelled else { return }
                        await self.loadMemories()
                    }
                }
                group.addTask {
                    for await _ in updates {
                        guard !Task.isCancelled else { return }
                        await self.loadMemories()
                    }
                }
                group.addTask {
                    for await _ in deletes {
                        guard !Task.isCancelled else { return }
                        await self.loadMemories()
                    }
                }
            }
        }
    }

    /// Subscribes to Realtime UPDATE events on the partner's `profiles` row so distance,
    /// widgets, and shared premium refresh when the partner's row changes.
    private func subscribeToPartnerProfile() {
        guard let couple = currentCouple, let myId = currentUser?.id else { return }
        let partnerId = couple.user1Id == myId ? couple.user2Id : couple.user1Id

        partnerLocationListenerTask?.cancel()
        partnerLocationListenerTask = Task {
            let channel = supabase.client.realtimeV2
                .channel("partner-profile-\(partnerId)")
            let updates = channel.postgresChange(
                UpdateAction.self,
                schema: "public",
                table: "profiles",
                filter: "id=eq.\(partnerId)"
            )
            do {
                try await channel.subscribeWithError()
            } catch {
                print("🚨 Partner-profile subscribe failed: \(error)")
                return
            }
            defer { Task { await self.supabase.client.realtimeV2.removeChannel(channel) } }

            for await _ in updates {
                guard !Task.isCancelled else { return }
                await loadPartnerProfile()
                await SubscriptionManager.shared.refreshSharedPremiumAccess(appState: self)
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

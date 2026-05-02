import CoreLocation
import Foundation
import Observation
import WidgetKit
import Supabase

/// Coordinate for map focus after saving a memory; explicit `Equatable` for SwiftUI `onChange`.
struct NewlyAddedMemoryCoordinate: Equatable {
    let latitude: Double
    let longitude: Double
}

/// App-wide session, profile, and pairing state.
@MainActor
@Observable
final class AppStateManager {
    private let supabase: SupabaseManager

    var currentUser: Profile?
    var currentCouple: Couple?
    var partnerProfile: Profile?
    var memories: [CoupleMemory] = []
    /// Set after saving a memory so the map can animate to it; cleared by the map after handling.
    var newlyAddedLocation: NewlyAddedMemoryCoordinate?
    var isLoading = true

    init(supabase: SupabaseManager = .shared) {
        self.supabase = supabase
    }

    /// Ensures auth, profile (with a random 6-digit code if new), and couple state are loaded.
    func initializeApp() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // 1. Check if user is actually logged in
            if await supabase.getSession() != nil {
                // 2. Fetch or create their database profile
                var profile = try await supabase.fetchProfile()
                if profile == nil {
                    print("👤 Creating new profile for authenticated user...")
                    try await Self.createProfileWithRetries(supabase: supabase)
                    profile = try await supabase.fetchProfile()
                }

                currentUser = profile
                currentCouple = try await supabase.fetchCurrentCouple()
                await loadPartnerProfile()
                print("✅ SUCCESS: Profile loaded.")
            } else {
                // Not logged in. Clear state so LoginView shows.
                currentUser = nil
                currentCouple = nil
                partnerProfile = nil
                print("🔒 User is not authenticated. Awaiting login.")
            }
        } catch {
            print("🚨 INIT ERROR: \(error)")
            currentUser = nil
            currentCouple = nil
            partnerProfile = nil
        }
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

    /// Pushes partner fields to the App Group UserDefaults and reloads widgets only when values change.
    private func updateWidgetData(partner: Profile) {
        guard let defaults = UserDefaults(suiteName: "group.forever.widget") else { return }

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

        // 5. Lock screen message
        if let msg = partner.latestMessage {
            let key = "partnerMessage"
            if defaults.string(forKey: key) != msg {
                defaults.set(msg, forKey: key)
                didChange = true
            }
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

        if didChange {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// After the user enters a partner code, links accounts and refreshes `currentCouple`.
    func linkWithPartner(code: String) async throws {
        let newlyFetchedCouple = try await supabase.linkPartner(code: code)
        currentCouple = newlyFetchedCouple
        guard let user = currentUser else { return }
        try await supabase.attachSoloMemoriesToCouple(coupleId: newlyFetchedCouple.id, creatorId: user.id)
        await loadMemories()
    }

    /// Deletes the relationship row and clears local pairing state.
    func unpair() async {
        guard let coupleId = currentCouple?.id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            // Delete the couple connection in Supabase first.
            try await supabase.deleteCouple(id: coupleId)

            // Reset local state so routing returns to pairing flow.
            currentCouple = nil
            partnerProfile = nil
            memories = []

            print("✅ Successfully unpaired. UI should now route to PairingView.")
        } catch {
            print("🚨 Failed to unpair: \(error)")
        }
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

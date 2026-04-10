import CoreLocation
import Foundation
import Observation
import WidgetKit
import Supabase

/// App-wide session, profile, and pairing state.
@MainActor
@Observable
final class AppStateManager {
    private let supabase: SupabaseManager

    var currentUser: Profile?
    var currentCouple: Couple?
    var partnerProfile: Profile?
    var isLoading = true

    init(supabase: SupabaseManager = .shared) {
        self.supabase = supabase
    }

    /// Ensures auth, profile (with a random 6-digit code if new), and couple state are loaded.
    func initializeApp() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if await supabase.getSession() == nil {
                print("🛜 No session found. Attempting Anonymous Sign-In...")
                try await supabase.signIn()
            }

            var profile = try await supabase.fetchProfile()
            if profile == nil {
                print("👤 No profile found. Creating a new one...")
                try await Self.createProfileWithRetries(supabase: supabase)
                profile = try await supabase.fetchProfile()
            }

            currentUser = profile
            currentCouple = try await supabase.fetchCurrentCouple()
            await loadPartnerProfile()
            print("✅ SUCCESS: Profile loaded. Code is: \(profile?.pairingCode ?? "Unknown")")

        } catch {
            // THIS IS THE MAGIC PART WE ARE ADDING
            print("🚨 SUPABASE ERROR: \(error.localizedDescription)")
            print("🚨 FULL ERROR DETAILS: \(error)")

            currentUser = nil
            currentCouple = nil
            partnerProfile = nil
        }
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

        // 2. Distance (ignore sub-mile float noise so GPS jitter does not spam reloads)
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
        currentCouple = try await supabase.linkPartner(code: code)
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

import CoreLocation
import Foundation
import Observation
import WidgetKit

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

    /// Calculates distance and pushes it to the App Group UserDefaults
    private func updateWidgetData(partner: Profile) {
        guard let defaults = UserDefaults(suiteName: "group.forever.widget") else { return }

        // 1. Sync Battery
        if let battery = partner.batteryLevel {
            defaults.set(battery, forKey: "partnerBattery")
        }

        // 2. Sync Distance
        if let myLat = currentUser?.latitude, let myLon = currentUser?.longitude,
           let pLat = partner.latitude, let pLon = partner.longitude {

            let myLocation = CLLocation(latitude: myLat, longitude: myLon)
            let partnerLocation = CLLocation(latitude: pLat, longitude: pLon)

            // Convert meters to miles
            let distanceInMeters = myLocation.distance(from: partnerLocation)
            let distanceInMiles = distanceInMeters / 1609.344

            defaults.set(distanceInMiles, forKey: "partnerDistance")
        }

        // 3. Force the widget to instantly refresh
        WidgetCenter.shared.reloadAllTimelines()
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

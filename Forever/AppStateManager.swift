import Foundation
import Observation

/// App-wide session, profile, and pairing state.
@MainActor
@Observable
final class AppStateManager {
    private let supabase: SupabaseManager

    var currentUser: Profile?
    var currentCouple: Couple?
    var isLoading = true

    init(supabase: SupabaseManager = SupabaseManager()) {
        self.supabase = supabase
    }

    /// Ensures auth, profile (with a random 6-digit code if new), and couple state are loaded.
    func initializeApp() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if await supabase.getSession() == nil {
                try await supabase.signIn()
            }
            var profile = try await supabase.fetchProfile()
            if profile == nil {
                try await Self.createProfileWithRetries(supabase: supabase)
                profile = try await supabase.fetchProfile()
            }
            currentUser = profile
            currentCouple = try await supabase.fetchCurrentCouple()
        } catch {
            currentUser = nil
            currentCouple = nil
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

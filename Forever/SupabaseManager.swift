import Foundation
import Supabase

enum PairingError: LocalizedError {
    case emptyCode
    case partnerNotFound

    var errorDescription: String? {
        switch self {
        case .emptyCode: "Enter a pairing code."
        case .partnerNotFound: "No partner found with that code."
        }
    }
}

/// Wraps `SupabaseClient` for auth and table access.
final class SupabaseManager {
    let client: SupabaseClient

    init(
        supabaseURL: URL = URL(string: "https://cdcnzkbxlyoxukxizfmd.supabase.co")!,
        supabaseKey: String = "sb_publishable_VygMgDm0S8and8KregtFyA_NF6tFRxK"
    ) {
        client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
    }

    /// Returns the cached session if present; otherwise `nil` (does not throw for missing session).
    func getSession() async -> Session? {
        do {
            return try await client.auth.session
        } catch {
            return nil
        }
    }

    /// Anonymous sign-in for a fresh session.
    func signIn() async throws {
        _ = try await client.auth.signInAnonymously()
    }

    /// Loads the profile row for the signed-in user, if it exists.
    func fetchProfile() async throws -> Profile? {
        let session = try await client.auth.session
        let rows: [Profile] = try await client.from("profiles")
            .select()
            .eq("id", value: session.user.id)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Inserts a profile for the current user with the given pairing code.
    func createProfile(code: String) async throws {
        let session = try await client.auth.session
        struct NewProfile: Encodable {
            let id: UUID
            let pairing_code: String
        }
        try await client.from("profiles")
            .insert(NewProfile(id: session.user.id, pairing_code: code))
            .execute()
    }

    /// Returns a couple row the user belongs to, if any.
    func fetchCurrentCouple() async throws -> Couple? {
        let session = try await client.auth.session
        let uid = session.user.id
        let asUser1: [Couple] = try await client.from("couples")
            .select()
            .eq("user1_id", value: uid)
            .limit(1)
            .execute()
            .value
        if let first = asUser1.first { return first }
        let asUser2: [Couple] = try await client.from("couples")
            .select()
            .eq("user2_id", value: uid)
            .limit(1)
            .execute()
            .value
        return asUser2.first
    }

    /// Resolves a partner by pairing code and creates a `couples` row.
    func linkPartner(code: String) async throws -> Couple {
        let session = try await client.auth.session
        let selfId = session.user.id
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PairingError.emptyCode }

        struct Params: Encodable {
            let p_code: String
        }
        let partnerId: UUID? = try await client.rpc(
            "find_partner_by_pairing_code",
            params: Params(p_code: trimmed)
        )
        .execute()
        .value

        guard let partnerId else { throw PairingError.partnerNotFound }

        struct NewCouple: Encodable {
            let user1_id: UUID
            let user2_id: UUID
        }

        let inserted: Couple = try await client.from("couples")
            .insert(NewCouple(user1_id: selfId, user2_id: partnerId))
            .select()
            .single()
            .execute()
            .value
        return inserted
    }
}

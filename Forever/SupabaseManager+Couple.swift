import Foundation
import Supabase

// Pairing: the current couple, linking by code, and unpairing.
extension SupabaseManager {
    /// Returns the canonical couple the user belongs to, if any. Both partners resolve the
    /// same earliest row so they share one Realtime topic and one persisted stroke history.
    func fetchCurrentCouple() async throws -> Couple? {
        let session = try await client.auth.session
        let uid = session.user.id
        let rows: [Couple] = try await client.from(DB.couples)
            .select()
            .or("user1_id.eq.\(uid),user2_id.eq.\(uid)")
            .order("created_at", ascending: true)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Atomically deletes the caller's couple plus its memories and drawings (server-side, RLS-safe).
    func unpairCouple() async throws {
        try await client.rpc("unpair_couple").execute()
    }

    /// Pairs with the owner of `code` on the server, which validates the code, rate-limits guesses,
    /// and returns the existing couple if the two are already linked.
    func linkPartner(code: String) async throws -> Couple {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PairingError.emptyCode }

        do {
            let rows: [Couple] = try await client
                .rpc("pair_with_code", params: PairWithCodeParams(p_code: trimmed))
                .execute()
                .value
            guard let couple = rows.first else { throw PairingError.partnerNotFound }
            return couple
        } catch let error as PostgrestError {
            throw PairingError(serverMessage: error.message) ?? error
        }
    }

    /// Fetches a couple row by id (includes shared board wallpaper URL).
    func fetchCouple(id: UUID) async throws -> Couple {
        try await client.from(DB.couples)
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }
}

// MARK: - DTOs

private nonisolated struct PairWithCodeParams: Encodable, Sendable {
    let p_code: String
}

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

    /// Resolves a partner by pairing code and returns the couple, reusing the existing
    /// row if the pair is already linked so both partners converge on one canonical couple.
    func linkPartner(code: String) async throws -> Couple {
        let session = try await client.auth.session
        let selfId = session.user.id
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PairingError.emptyCode }

        let partnerId: UUID? = try await client.rpc(
            "find_partner_by_pairing_code",
            params: FindPartnerParams(p_code: trimmed)
        )
        .execute()
        .value

        guard let partnerId else { throw PairingError.partnerNotFound }

        if let existing = try await fetchCouple(between: selfId, and: partnerId) {
            return existing
        }

        do {
            return try await client.from(DB.couples)
                .insert(NewCoupleInsert(user1_id: selfId, user2_id: partnerId))
                .select()
                .single()
                .execute()
                .value
        } catch {
            // A simultaneous link from the partner can win the `couples_unique_pair`
            // race; fall back to the now-existing canonical row.
            if let existing = try await fetchCouple(between: selfId, and: partnerId) {
                return existing
            }
            throw error
        }
    }

    /// Returns the canonical (earliest) couple linking two users in either direction, if any.
    private func fetchCouple(between userA: UUID, and userB: UUID) async throws -> Couple? {
        let rows: [Couple] = try await client.from(DB.couples)
            .select()
            .or("and(user1_id.eq.\(userA),user2_id.eq.\(userB)),and(user1_id.eq.\(userB),user2_id.eq.\(userA))")
            .order("created_at", ascending: true)
            .limit(1)
            .execute()
            .value
        return rows.first
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

private nonisolated struct FindPartnerParams: Encodable, Sendable {
    let p_code: String
}

private nonisolated struct NewCoupleInsert: Encodable, Sendable {
    let user1_id: UUID
    let user2_id: UUID
}

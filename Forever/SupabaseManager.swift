import Foundation
import Supabase

enum DB {
    static let profiles = "profiles"
    static let couples = "couples"
    static let memories = "memories"
    static let notesBucket = "notes"
}

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
    static let shared = SupabaseManager()

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

    func signInWithApple(idToken: String, nonce: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Loads the profile row for the signed-in user, if it exists.
    func fetchProfile() async throws -> Profile? {
        let session = try await client.auth.session
        let rows: [Profile] = try await client.from(DB.profiles)
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
        try await client.from(DB.profiles)
            .insert(NewProfileInsert(id: session.user.id, pairing_code: code))
            .execute()
    }

    /// Returns a couple row the user belongs to, if any.
    func fetchCurrentCouple() async throws -> Couple? {
        let session = try await client.auth.session
        let uid = session.user.id
        let asUser1: [Couple] = try await client.from(DB.couples)
            .select()
            .eq("user1_id", value: uid)
            .limit(1)
            .execute()
            .value
        if let first = asUser1.first { return first }
        let asUser2: [Couple] = try await client.from(DB.couples)
            .select()
            .eq("user2_id", value: uid)
            .limit(1)
            .execute()
            .value
        return asUser2.first
    }

    func fetchMemories(coupleId: UUID?, creatorId: UUID) async throws -> [CoupleMemory] {
        struct MemoryResponse: Decodable {
            let id: UUID
            let couple_id: UUID?
            let creator_id: UUID
            let image_urls: [String]?
            let image_url: String?
            let latitude: Double
            let longitude: Double
            let created_at: String
            let note: String?
        }

        let response: [MemoryResponse]
        if let coupleId {
            response = try await client.from(DB.memories)
                .select()
                .eq("couple_id", value: coupleId)
                .execute()
                .value
        } else {
            response = try await client.from(DB.memories)
                .select()
                .eq("creator_id", value: creatorId)
                .is("couple_id", value: nil)
                .execute()
                .value
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return response.compactMap { mem in
            var urls: [URL] = []
            if let arr = mem.image_urls {
                urls = arr.compactMap { URL(string: $0) }
            }
            if urls.isEmpty, let single = mem.image_url, let url = URL(string: single) {
                urls = [url]
            }
            guard !urls.isEmpty else { return nil }
            let date = formatter.date(from: mem.created_at) ?? Date()
            return CoupleMemory(
                id: mem.id,
                coupleId: mem.couple_id,
                creatorId: mem.creator_id,
                imageUrls: urls,
                latitude: mem.latitude,
                longitude: mem.longitude,
                createdAt: date,
                note: mem.note
            )
        }
    }

    func uploadMemoryImage(data: Data, coupleId: UUID?, creatorId: UUID) async throws -> URL {
        let folderPrefix = coupleId.map(\.uuidString) ?? "solo/\(creatorId.uuidString)"
        let fileName = "\(folderPrefix)/\(UUID().uuidString).jpg"
        try await client.storage
            .from(DB.notesBucket)
            .upload(
                fileName,
                data: data,
                options: FileOptions(contentType: "image/jpeg")
            )
        return try client.storage.from(DB.notesBucket).getPublicURL(path: fileName)
    }

    func insertMemory(coupleId: UUID?, creatorId: UUID, imageUrls: [URL], lat: Double, lng: Double, date: Date, note: String) async throws {
        struct InsertMemory: Encodable, Sendable {
            let couple_id: UUID?
            let creator_id: UUID
            let image_urls: [String]
            let latitude: Double
            let longitude: Double
            let created_at: String
            let note: String?
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let payload = InsertMemory(
            couple_id: coupleId,
            creator_id: creatorId,
            image_urls: imageUrls.map(\.absoluteString),
            latitude: lat,
            longitude: lng,
            created_at: formatter.string(from: date),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note
        )

        try await client.from(DB.memories)
            .insert(payload)
            .execute()
    }

    /// Assigns the new couple to all solo memories created by this user.
    func attachSoloMemoriesToCouple(coupleId: UUID, creatorId: UUID) async throws {
        try await client.from(DB.memories)
            .update(MemoryCoupleAttachUpdate(couple_id: coupleId))
            .eq("creator_id", value: creatorId)
            .is("couple_id", value: nil)
            .execute()
    }

    func deleteMemory(id: UUID) async throws {
        try await client.from(DB.memories)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Deletes the couple row to unpair both users.
    func deleteCouple(id: UUID) async throws {
        try await client.database
            .from(DB.couples)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Resolves a partner by pairing code and creates a `couples` row.
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

        let inserted: Couple = try await client.from(DB.couples)
            .insert(NewCoupleInsert(user1_id: selfId, user2_id: partnerId))
            .select()
            .single()
            .execute()
            .value
        return inserted
    }

    /// Writes latest location and battery snapshot for the signed-in user.
    func updateAmbientData(latitude: Double, longitude: Double, batteryLevel: Int) async throws {
        let session = try await client.auth.session
        try await client.from(DB.profiles)
            .update(AmbientDataUpdate(latitude: latitude, longitude: longitude, battery_level: batteryLevel))
            .eq("id", value: session.user.id)
            .execute()
    }

    func uploadNoteImage(data: Data) async throws -> String {
        let path = "\(UUID().uuidString).png"

        try await client.storage
            .from(DB.notesBucket)
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/png")
            )

        let publicUrl = try client.storage.from(DB.notesBucket).getPublicURL(path: path)
        return publicUrl.absoluteString
    }

    func updateLatestNoteUrl(url: String) async throws {
        let session = try await client.auth.session
        let myId = session.user.id

        try await client.from(DB.profiles)
            .update(NoteUpdateDTO(latest_note_url: url))
            .eq("id", value: myId)
            .execute()
    }

    func updateDeviceToken(_ token: String) async throws {
        let session = try await client.auth.session
        let myId = session.user.id

        try await client.from(DB.profiles)
            .update(DeviceTokenUpdateDTO(device_token: token))
            .eq("id", value: myId)
            .execute()
    }

    /// Updates display name and anniversary date for the signed-in user.
    func updateProfileDetails(name: String, anniversary: Date) async throws {
        let session = try await client.auth.session
        struct UpdateDTO: Encodable, Sendable {
            let display_name: String
            let anniversary_date: Date
        }
        try await client.from(DB.profiles)
            .update(UpdateDTO(display_name: name, anniversary_date: anniversary))
            .eq("id", value: session.user.id)
            .execute()
    }

    /// Sends a lock screen message for the signed-in user.
    func sendLockScreenMessage(_ message: String) async throws {
        let session = try await client.auth.session
        struct MsgDTO: Encodable, Sendable {
            let latest_message: String
        }
        try await client.from(DB.profiles)
            .update(MsgDTO(latest_message: message))
            .eq("id", value: session.user.id)
            .execute()
    }
}

// MARK: - DTOs (Data Transfer Objects)
// Moving these here and adding Sendable fixes the Swift 6 concurrency errors.

private nonisolated struct NewProfileInsert: Encodable, Sendable {
    let id: UUID
    let pairing_code: String
}

private nonisolated struct FindPartnerParams: Encodable, Sendable {
    let p_code: String
}

private nonisolated struct NewCoupleInsert: Encodable, Sendable {
    let user1_id: UUID
    let user2_id: UUID
}

private nonisolated struct AmbientDataUpdate: Encodable, Sendable {
    let latitude: Double
    let longitude: Double
    let battery_level: Int
}

private nonisolated struct NoteUpdateDTO: Encodable, Sendable {
    let latest_note_url: String
}

private nonisolated struct DeviceTokenUpdateDTO: Encodable, Sendable {
    let device_token: String
}

private nonisolated struct MemoryCoupleAttachUpdate: Encodable, Sendable {
    let couple_id: UUID
}

import Foundation
import Supabase

// Shared map memories and their photos.
extension SupabaseManager {
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

    func updateMemory(id: UUID, imageUrls: [URL], lat: Double, lng: Double, date: Date, note: String) async throws {
        struct UpdatePayload: Encodable, Sendable {
            let image_urls: [String]
            let latitude: Double
            let longitude: Double
            let created_at: String
            let note: String?
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = UpdatePayload(
            image_urls: imageUrls.map(\.absoluteString),
            latitude: lat,
            longitude: lng,
            created_at: formatter.string(from: date),
            note: cleanNote.isEmpty ? nil : cleanNote
        )

        try await client.from(DB.memories)
            .update(payload)
            .eq("id", value: id)
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

    /// Persists note text; empty string clears the note in the database.
    func updateMemoryNote(id: UUID, note: String) async throws {
        struct UpdatePayload: Encodable, Sendable {
            let note: String?

            enum CodingKeys: String, CodingKey { case note }

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(note, forKey: .note)
            }
        }

        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = UpdatePayload(note: cleanNote.isEmpty ? nil : cleanNote)

        try await client.from(DB.memories)
            .update(payload)
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - DTOs

private nonisolated struct MemoryCoupleAttachUpdate: Encodable, Sendable {
    let couple_id: UUID
}

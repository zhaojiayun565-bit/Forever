import Foundation
import os
import Supabase

// Cherished text screenshots and their Realtime sync.
extension SupabaseManager {
    /// Loads all cherished texts for a couple, newest first.
    func fetchCherishedTexts(coupleId: UUID) async throws -> [RemoteCherishedText] {
        let rows: [CherishedTextRow] = try await client.from(DB.cherishedTexts)
            .select("id, couple_id, image_url, extracted_text, created_at")
            .eq("couple_id", value: coupleId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.compactMap { $0.toRemoteCherishedText() }
    }

    /// Returns whether a cherished text row exists for this couple.
    func cherishedTextExists(id: UUID, coupleId: UUID) async throws -> Bool {
        struct IdRow: Decodable, Sendable {
            let id: UUID
        }
        let rows: [IdRow] = try await client.from(DB.cherishedTexts)
            .select("id")
            .eq("id", value: id)
            .eq("couple_id", value: coupleId)
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }

    /// Uploads a screenshot to the cherished texts bucket.
    func uploadCherishedTextImage(data: Data, coupleId: UUID, textId: UUID) async throws -> URL {
        let path = Self.cherishedTextStoragePath(coupleId: coupleId, textId: textId)
        try await client.storage
            .from(DB.cherishedTextsBucket)
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        return try client.storage.from(DB.cherishedTextsBucket).getPublicURL(path: path)
    }

    /// Inserts a cherished text row (client-supplied id keeps local and remote in sync).
    func insertCherishedText(
        id: UUID,
        coupleId: UUID,
        creatorId: UUID,
        imageURL: URL,
        extractedText: String,
        createdAt: Date
    ) async throws {
        let payload = CherishedTextInsert(
            id: id,
            couple_id: coupleId,
            creator_id: creatorId,
            author_id: creatorId,
            image_url: imageURL.absoluteString,
            extracted_text: extractedText,
            created_at: createdAt.formatted(Self.iso8601Format)
        )
        try await client.from(DB.cherishedTexts)
            .insert(payload)
            .execute()
    }

    /// Deletes a cherished text row and its storage object.
    func deleteCherishedText(id: UUID, imageURL: URL?) async throws {
        if let imageURL {
            try await deleteCherishedTextImage(at: imageURL)
        }
        try await client.from(DB.cherishedTexts)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Removes the screenshot from storage (current bucket or legacy notes/cherished paths).
    func deleteCherishedTextImage(at imageURL: URL) async throws {
        if let path = Self.storagePath(from: imageURL, bucket: DB.cherishedTextsBucket) {
            try await client.storage
                .from(DB.cherishedTextsBucket)
                .remove(paths: [path])
            return
        }

        if let path = Self.storagePath(from: imageURL, bucket: DB.notesBucket),
           path.hasPrefix("cherished/") {
            try await client.storage
                .from(DB.notesBucket)
                .remove(paths: [path])
        }
    }

    /// Subscribes to Realtime INSERT/DELETE on `cherished_texts` for a couple.
    /// The returned task runs until cancelled; call `onChange` to merge remote updates.
    func listenForCherishedTextChanges(
        coupleId: UUID,
        onChange: @escaping @MainActor @Sendable () async -> Void
    ) -> Task<Void, Never> {
        Task {
            let topic = "cherished-texts-\(coupleId.uuidString)"
            let channel = await preparedRealtimeChannel(topic)
            guard !Task.isCancelled else { return }

            let filter = RealtimePostgresFilter.eq("couple_id", value: coupleId)
            let inserts = channel.postgresChange(
                InsertAction.self, schema: "public", table: DB.cherishedTexts, filter: filter
            )
            let deletes = channel.postgresChange(
                DeleteAction.self, schema: "public", table: DB.cherishedTexts, filter: filter
            )

            let consumeTask = Task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await _ in inserts {
                            guard !Task.isCancelled else { return }
                            await onChange()
                        }
                    }
                    group.addTask {
                        for await _ in deletes {
                            guard !Task.isCancelled else { return }
                            await onChange()
                        }
                    }
                }
            }

            do {
                try await channel.subscribeWithError()
            } catch {
                consumeTask.cancel()
                Log.realtime.error("Cherished texts subscribe failed: \(String(describing: error))")
                await tearDownRealtimeChannel(topic)
                return
            }

            await consumeTask.value
            await tearDownRealtimeChannel(topic)
        }
    }

    /// Builds a lowercase UUID storage path for cherished text screenshots.
    static func cherishedTextStoragePath(coupleId: UUID, textId: UUID) -> String {
        "\(coupleId.uuidString.lowercased())/\(textId.uuidString.lowercased()).jpg"
    }
}

// MARK: - DTOs

struct RemoteCherishedText: Sendable, Identifiable {
    let id: UUID
    let coupleId: UUID
    let imageURL: URL
    let extractedText: String
    let createdAt: Date
}

private nonisolated struct CherishedTextInsert: Encodable, Sendable {
    let id: UUID
    let couple_id: UUID
    let creator_id: UUID
    let author_id: UUID
    let image_url: String
    let extracted_text: String
    let created_at: String
}

private nonisolated struct CherishedTextRow: Decodable, Sendable {
    let id: UUID
    let couple_id: UUID
    let image_url: String
    let extracted_text: String
    let created_at: String

    func toRemoteCherishedText() -> RemoteCherishedText? {
        guard let imageURL = URL(string: image_url) else { return nil }
        let date = (try? SupabaseManager.iso8601Format.parse(created_at)) ?? Date()
        return RemoteCherishedText(
            id: id,
            coupleId: couple_id,
            imageURL: imageURL,
            extractedText: extracted_text,
            createdAt: date
        )
    }
}

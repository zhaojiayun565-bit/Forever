import Foundation
import Supabase

enum DB {
    static let profiles = "profiles"
    static let couples = "couples"
    static let memories = "memories"
    static let notesBucket = "notes"
    static let drawingStrokes = "drawing_strokes"
    static let drawingArchive = "drawing_archive"
    static let cherishedTexts = "cherished_texts"
    static let cherishedTextsBucket = "cherished_texts_images"
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
final class SupabaseManager: Sendable {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    init(
        supabaseURL: URL = URL(string: "https://cdcnzkbxlyoxukxizfmd.supabase.co")!,
        supabaseKey: String = "sb_publishable_VygMgDm0S8and8KregtFyA_NF6tFRxK"
    ) {
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true),
                realtime: .init(logLevel: .info)
            )
        )
    }

    /// Returns the cached session if present; otherwise `nil` (does not throw for missing session).
    func getSession() async -> Session? {
        do {
            return try await client.auth.session
        } catch {
            return nil
        }
    }

    /// Returns the signed-in user's id, or nil when unauthenticated.
    func currentUserId() async -> UUID? {
        await getSession()?.user.id
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    /// Creates an anonymous auth session and ensures a profile exists for pairing.
    func signInAnonymously() async throws -> String {
        let session = try await client.auth.signInAnonymously()
        let userId = session.user.id.uuidString
        try await createProfileIfMissing(userId: userId, fullName: "Anonymous Tester", avatarUrl: nil)
        return userId
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

    /// Ensures a profile row exists for the provided user id.
    func createProfileIfMissing(userId: String, fullName: String, avatarUrl: String?) async throws {
        _ = avatarUrl
        guard let uuid = UUID(uuidString: userId) else { return }
        let existing: [Profile] = try await client.from(DB.profiles)
            .select()
            .eq("id", value: uuid)
            .limit(1)
            .execute()
            .value
        guard existing.first == nil else { return }

        for _ in 0 ..< 10 {
            do {
                try await client.from(DB.profiles)
                    .insert(ProfileInsertWithName(
                        id: uuid,
                        pairing_code: Self.randomSixDigitCode(),
                        display_name: fullName
                    ))
                    .execute()
                return
            } catch {
                continue
            }
        }

        try await client.from(DB.profiles)
            .insert(ProfileInsertWithName(
                id: uuid,
                pairing_code: Self.randomSixDigitCode(),
                display_name: fullName
            ))
            .execute()
    }

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
        }

        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = UpdatePayload(note: cleanNote.isEmpty ? nil : cleanNote)

        try await client.from(DB.memories)
            .update(payload)
            .eq("id", value: id)
            .execute()
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

    /// Uploads a profile photo and saves its public URL on the signed-in user's profile.
    func uploadProfileAvatar(_ imageData: Data) async throws -> String {
        let session = try await client.auth.session
        let path = "avatars/\(session.user.id.uuidString).jpg"

        try await client.storage
            .from(DB.notesBucket)
            .upload(
                path,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )

        let publicUrl = try client.storage.from(DB.notesBucket).getPublicURL(path: path)
        let urlString = publicUrl.absoluteString

        struct AvatarUpdate: Encodable, Sendable {
            let avatar_url: String
        }
        try await client.from(DB.profiles)
            .update(AvatarUpdate(avatar_url: urlString))
            .eq("id", value: session.user.id)
            .execute()

        return urlString
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

    /// Stamps `drawing_started_at` so the profiles webhook pushes a "started drawing" alert to the partner.
    func markDrawingStarted() async throws {
        let session = try await client.auth.session
        struct StartedDTO: Encodable, Sendable {
            let drawing_started_at: String
        }
        let now = ISO8601DateFormatter().string(from: Date())
        try await client.from(DB.profiles)
            .update(StartedDTO(drawing_started_at: now))
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

    // MARK: - Drawing Board

    /// Loads all persisted strokes for a couple's board, oldest first.
    func fetchStrokes(coupleId: UUID) async throws -> [DrawStroke] {
        let rows: [DrawingStrokeRow] = try await client.from(DB.drawingStrokes)
            .select()
            .eq("couple_id", value: coupleId)
            .order("created_at", ascending: true)
            .execute()
            .value
        return rows.map { $0.toDrawStroke() }
    }

    /// Persists a completed stroke (called once per stroke, never per point).
    func insertStroke(_ payload: DrawingStrokeInsert) async throws {
        try await client.from(DB.drawingStrokes)
            .insert(payload)
            .execute()
    }

    /// Removes a single stroke (powers Undo).
    func deleteStroke(id: UUID) async throws {
        try await client.from(DB.drawingStrokes)
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Wipes every stroke on a couple's board (powers Clear).
    func clearStrokes(coupleId: UUID) async throws {
        try await client.from(DB.drawingStrokes)
            .delete()
            .eq("couple_id", value: coupleId)
            .execute()
    }

    /// Uploads a full-board archive JPEG to the notes bucket.
    func uploadArchiveImage(data: Data) async throws -> URL {
        let path = "archive/\(UUID().uuidString).jpg"
        try await client.storage
            .from(DB.notesBucket)
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/jpeg")
            )
        return try client.storage.from(DB.notesBucket).getPublicURL(path: path)
    }

    /// Inserts a sent drawing snapshot into the shared archive.
    func insertArchivedDrawing(coupleId: UUID, authorId: UUID, imageUrl: URL) async throws {
        let payload = DrawingArchiveInsert(
            couple_id: coupleId,
            author_id: authorId,
            image_url: imageUrl.absoluteString
        )
        try await client.from(DB.drawingArchive)
            .insert(payload)
            .execute()
    }

    /// Loads archived drawings for a couple, newest first.
    func fetchArchivedDrawings(coupleId: UUID) async throws -> [ArchivedDrawing] {
        let rows: [DrawingArchiveRow] = try await client.from(DB.drawingArchive)
            .select()
            .eq("couple_id", value: coupleId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.map { $0.toArchivedDrawing() }
    }

    // MARK: - Cherished Texts

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
            created_at: Self.iso8601Formatter.string(from: createdAt)
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
            let channel = client.realtimeV2.channel("cherished-texts-\(coupleId.uuidString)")
            let filter = "couple_id=eq.\(coupleId.uuidString)"
            let inserts = channel.postgresChange(
                InsertAction.self, schema: "public", table: DB.cherishedTexts, filter: filter
            )
            let deletes = channel.postgresChange(
                DeleteAction.self, schema: "public", table: DB.cherishedTexts, filter: filter
            )
            do {
                try await channel.subscribeWithError()
            } catch {
                print("🚨 Cherished texts subscribe failed: \(error)")
                return
            }
            defer { Task { await self.client.realtimeV2.removeChannel(channel) } }

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
    }

    fileprivate static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Builds a lowercase UUID storage path for cherished text screenshots.
    fileprivate static func cherishedTextStoragePath(coupleId: UUID, textId: UUID) -> String {
        "\(coupleId.uuidString.lowercased())/\(textId.uuidString.lowercased()).jpg"
    }

    /// Extracts the object path from a Supabase public storage URL.
    fileprivate static func storagePath(from url: URL, bucket: String) -> String? {
        let marker = "/storage/v1/object/public/\(bucket)/"
        let absolute = url.absoluteString
        guard let range = absolute.range(of: marker) else { return nil }
        return String(absolute[range.upperBound...])
    }

}

// MARK: - DTOs (Data Transfer Objects)
// Moving these here and adding Sendable fixes the Swift 6 concurrency errors.

extension SupabaseManager {
    fileprivate static func randomSixDigitCode() -> String {
        String(format: "%06d", Int.random(in: 0 ... 999_999))
    }
}

private nonisolated struct NewProfileInsert: Encodable, Sendable {
    let id: UUID
    let pairing_code: String
}

private nonisolated struct ProfileInsertWithName: Encodable, Sendable {
    let id: UUID
    let pairing_code: String
    let display_name: String
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

private nonisolated struct DrawingArchiveInsert: Encodable, Sendable {
    let couple_id: UUID
    let author_id: UUID
    let image_url: String
}

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
        let date = SupabaseManager.iso8601Formatter.date(from: created_at) ?? Date()
        return RemoteCherishedText(
            id: id,
            coupleId: couple_id,
            imageURL: imageURL,
            extractedText: extracted_text,
            createdAt: date
        )
    }
}

private nonisolated struct DrawingArchiveRow: Decodable, Sendable {
    let id: UUID
    let author_id: UUID
    let image_url: String
    let created_at: String

    func toArchivedDrawing() -> ArchivedDrawing {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: created_at) ?? Date()
        return ArchivedDrawing(
            id: id,
            authorId: author_id,
            imageUrl: URL(string: image_url)!,
            createdAt: date
        )
    }
}

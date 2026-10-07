import Foundation
import Supabase

// Shared drawing board strokes, wallpaper, partner note and archive.
extension SupabaseManager {
    func uploadNoteImage(data: Data) async throws -> String {
        let path = "\(UUID().uuidString).jpg"

        try await client.storage
            .from(DB.notesBucket)
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/jpeg")
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

    /// Uploads the shared board wallpaper for a couple (upserts at a stable path).
    func uploadBoardWallpaper(data: Data, coupleId: UUID) async throws -> String {
        let path = "wallpaper/\(coupleId.uuidString).jpg"
        try await client.storage
            .from(DB.notesBucket)
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        let publicUrl = try client.storage.from(DB.notesBucket).getPublicURL(path: path)
        return publicUrl.absoluteString
    }

    /// Persists the shared board wallpaper URL and actor on the couple row.
    func updateBoardWallpaperUrl(coupleId: UUID, url: String) async throws {
        let session = try await client.auth.session
        try await client.from(DB.couples)
            .update(BoardWallpaperUpdate(
                board_wallpaper_url: url,
                board_wallpaper_updated_by: session.user.id
            ))
            .eq("id", value: coupleId)
            .execute()
    }

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
}

// MARK: - DTOs

private nonisolated struct NoteUpdateDTO: Encodable, Sendable {
    let latest_note_url: String
}

private nonisolated struct BoardWallpaperUpdate: Encodable, Sendable {
    let board_wallpaper_url: String
    let board_wallpaper_updated_by: UUID
}

private nonisolated struct DrawingArchiveInsert: Encodable, Sendable {
    let couple_id: UUID
    let author_id: UUID
    let image_url: String
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

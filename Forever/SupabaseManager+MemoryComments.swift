import Foundation
import Supabase

// Comment threads on shared map memories.
extension SupabaseManager {
    /// Loads a memory's comments, oldest first.
    func fetchMemoryComments(memoryId: UUID) async throws -> [MemoryComment] {
        try await client.from(DB.memoryComments)
            .select()
            .eq("memory_id", value: memoryId)
            .order("created_at", ascending: true)
            .execute()
            .value
    }

    /// Inserts a comment by the signed-in user and returns the stored row.
    func insertMemoryComment(memoryId: UUID, authorId: UUID, body: String) async throws -> MemoryComment {
        try await client.from(DB.memoryComments)
            .insert(MemoryCommentInsert(memory_id: memoryId, author_id: authorId, body: body))
            .select()
            .single()
            .execute()
            .value
    }

    func deleteMemoryComment(id: UUID) async throws {
        try await client.from(DB.memoryComments)
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

private nonisolated struct MemoryCommentInsert: Encodable, Sendable {
    let memory_id: UUID
    let author_id: UUID
    let body: String
}

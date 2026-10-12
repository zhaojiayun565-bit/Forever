import Foundation
import Observation
import Supabase
import os

/// Loads, live-syncs, posts, and deletes the comment thread for one shared memory.
@MainActor
@Observable
final class MemoryCommentsViewModel {
    let memoryId: UUID
    private(set) var comments: [MemoryComment] = []
    private(set) var isLoading = true
    private(set) var isSending = false
    var errorMessage: String?

    private let supabase: SupabaseManager
    private let realtime: RealtimeListenerRegistry
    private var topic: String { "memory-comments-\(memoryId)" }

    init(memoryId: UUID, supabase: SupabaseManager = .shared, realtime: RealtimeListenerRegistry) {
        self.memoryId = memoryId
        self.supabase = supabase
        self.realtime = realtime
    }

    /// Fetches the thread and subscribes to partner changes while the thread is on screen.
    func start() async {
        startListening()
        await reload()
    }

    func stop() {
        realtime.stop(topic)
    }

    func reload() async {
        defer { isLoading = false }
        do {
            comments = try await supabase.fetchMemoryComments(memoryId: memoryId)
        } catch {
            Log.data.error("Failed to load memory comments: \(String(describing: error))")
        }
    }

    /// Posts `text` as the current user; returns whether it was saved.
    func send(_ text: String, authorId: UUID) async -> Bool {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !isSending else { return false }
        isSending = true
        defer { isSending = false }
        do {
            let comment = try await supabase.insertMemoryComment(memoryId: memoryId, authorId: authorId, body: body)
            merge(comment)
            return true
        } catch {
            errorMessage = error.localizedDescription
            Log.data.error("Failed to post memory comment: \(String(describing: error))")
            return false
        }
    }

    func delete(_ comment: MemoryComment) async {
        let previous = comments
        comments.removeAll { $0.id == comment.id }
        do {
            try await supabase.deleteMemoryComment(id: comment.id)
        } catch {
            comments = previous
            errorMessage = error.localizedDescription
            Log.data.error("Failed to delete memory comment: \(String(describing: error))")
        }
    }

    private func merge(_ comment: MemoryComment) {
        guard !comments.contains(where: { $0.id == comment.id }) else { return }
        comments.append(comment)
        comments.sort { $0.createdAt < $1.createdAt }
    }

    // Delete events can't be filtered server-side; match comment ids client-side.
    private func startListening() {
        realtime.start(topic) { [weak self, memoryId] channel in
            let inserts = channel.postgresChange(
                InsertAction.self, schema: "public", table: DB.memoryComments,
                filter: .eq("memory_id", value: memoryId)
            )
            let deletes = channel.postgresChange(DeleteAction.self, schema: "public", table: DB.memoryComments)
            return { [weak self] in
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { [weak self] in
                        for await _ in inserts {
                            let viewModel = self
                            await viewModel?.reload()
                        }
                    }
                    group.addTask { [weak self] in
                        for await action in deletes {
                            guard let id = action.oldRecord["id"]?.stringValue.flatMap(UUID.init(uuidString:)) else { continue }
                            let viewModel = self
                            await MainActor.run { viewModel?.comments.removeAll { $0.id == id } }
                        }
                    }
                }
            }
        }
    }
}

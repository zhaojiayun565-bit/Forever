import Foundation
import Observation
import os

/// Loads and holds shared drawing archive entries for the Archive tab.
@MainActor
@Observable
final class ArchiveViewModel {
    private let supabase: SupabaseManager

    var drawings: [ArchivedDrawing] = []
    var isLoading = false

    init(supabase: SupabaseManager = .shared) {
        self.supabase = supabase
    }

    /// Fetches archived drawings for the current couple, newest first.
    func load(coupleId: UUID?) async {
        guard let coupleId else {
            drawings = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            drawings = try await supabase.fetchArchivedDrawings(coupleId: coupleId)
        } catch {
            Log.data.error("Failed to load archive: \(String(describing: error))")
        }
    }
}

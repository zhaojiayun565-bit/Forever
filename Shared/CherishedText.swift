import Foundation
import SwiftData

@Model
final class CherishedText {
    var id: UUID
    var imageData: Data
    var extractedText: String
    var dateAdded: Date
    /// Whether this row has been pushed to Supabase (local-only until paired + synced).
    var isSynced: Bool = false
    /// Public storage URL after upload; nil while solo or pending sync.
    var remoteImageURL: String? = nil

    init(
        id: UUID = UUID(),
        imageData: Data,
        extractedText: String,
        dateAdded: Date = .now,
        isSynced: Bool = false,
        remoteImageURL: String? = nil
    ) {
        self.id = id
        self.imageData = imageData
        self.extractedText = extractedText
        self.dateAdded = dateAdded
        self.isSynced = isSynced
        self.remoteImageURL = remoteImageURL
    }
}

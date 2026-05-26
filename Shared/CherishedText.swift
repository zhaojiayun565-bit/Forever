import Foundation
import SwiftData

@Model
final class CherishedText {
    var id: UUID
    var imageData: Data
    var extractedText: String
    var dateAdded: Date

    init(
        id: UUID = UUID(),
        imageData: Data,
        extractedText: String,
        dateAdded: Date = .now
    ) {
        self.id = id
        self.imageData = imageData
        self.extractedText = extractedText
        self.dateAdded = dateAdded
    }
}

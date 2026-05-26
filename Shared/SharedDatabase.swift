import Foundation
import SwiftData

enum SharedDatabase {
    static let appGroupIdentifier = "group.com.jiayunzhao.Forever"

    static let shared: ModelContainer = {
        let schema = Schema([CherishedText.self])
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            fatalError("App Group container unavailable: \(appGroupIdentifier)")
        }

        let storeURL = groupURL.appending(path: "CherishedTexts.store")
        let configuration = ModelConfiguration(url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create shared ModelContainer: \(error)")
        }
    }()

    @MainActor
    static var context: ModelContext {
        shared.mainContext
    }
}

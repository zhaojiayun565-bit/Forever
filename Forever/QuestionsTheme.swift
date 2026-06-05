import SwiftUI

/// Shared design tokens for the Questions feature.
enum QuestionsTheme {
    static let accent = Color(red: 1, green: 90.0 / 255.0, blue: 95.0 / 255.0)
    static let cardBackground = Color(red: 250.0 / 255.0, green: 250.0 / 255.0, blue: 250.0 / 255.0)

    /// Card fill that adapts to dark mode.
    static func cardFill(colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(UIColor.secondarySystemGroupedBackground)
            : cardBackground
    }
}

/// Answer-to-reveal state for a single question.
enum AnswerRevealState: Equatable {
    case unanswered
    case waiting
    case revealed
}

/// Picks the same daily question for both partners using a deterministic hash.
enum DailyQuestionSelector {
    /// Returns today's question from the daily pool for a couple.
    static func todaysQuestion(
        from pool: [Question],
        coupleId: UUID,
        date: Date = .now
    ) -> Question? {
        guard !pool.isEmpty else { return nil }
        let sorted = pool.sorted { $0.id.uuidString < $1.id.uuidString }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateKey = formatter.string(from: date)
        let seed = coupleId.uuidString.lowercased() + dateKey
        let index = Int(stableHash(seed) % UInt64(sorted.count))
        return sorted[index]
    }

    private static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return hash
    }
}

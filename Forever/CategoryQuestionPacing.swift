import Foundation

/// Evaluates the couple-wide "one category question per day" pacing rules.
enum CategoryQuestionPacing {
    static let dailySparkCategoryTitle = "The Daily Spark"

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// True when the couple used today's single non-daily question slot.
    static func hasAnsweredAnyCategoryQuestionToday(
        answers: [CoupleAnswer],
        questionsById: [UUID: Question],
        date: Date = .now
    ) -> Bool {
        answers.contains { answer in
            guard let question = questionsById[answer.questionId], !question.isDaily else {
                return false
            }
            return answer.wasAnsweredOnUTC(day: date)
        }
    }

    /// Today's Us-tab daily question id (nil if pool empty).
    static func todaysDailyQuestionId(
        dailyPool: [Question],
        coupleId: UUID,
        date: Date = .now
    ) -> UUID? {
        DailyQuestionSelector.todaysQuestion(from: dailyPool, coupleId: coupleId, date: date)?.id
    }

    /// Whether a question row in a category list should be blurred and untappable.
    static func isQuestionLocked(
        question: Question,
        sortedQuestions: [Question],
        answers: [UUID: CoupleAnswer],
        hasAnsweredAnyCategoryQuestionToday: Bool,
        todaysDailyQuestionId: UUID?,
        categoryTitle: String
    ) -> Bool {
        if hasAnyProgress(answers[question.id]) {
            return false
        }

        if hasAnsweredAnyCategoryQuestionToday {
            return true
        }

        if categoryTitle == dailySparkCategoryTitle {
            return question.id != todaysDailyQuestionId
        }

        guard let firstOpenIndex = sortedQuestions.firstIndex(where: { !hasAnyProgress(answers[$0.id]) }) else {
            return true
        }

        guard let questionIndex = sortedQuestions.firstIndex(where: { $0.id == question.id }) else {
            return true
        }

        return questionIndex != firstOpenIndex
    }

    /// Sorted questions for stable list ordering.
    static func sortedQuestions(_ questions: [Question]) -> [Question] {
        questions.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private static func hasAnyProgress(_ answer: CoupleAnswer?) -> Bool {
        guard let answer else { return false }
        return answer.partnerAAnsweredAt != nil || answer.partnerBAnsweredAt != nil
    }
}

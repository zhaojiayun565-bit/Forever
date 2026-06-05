import Foundation
import Observation

/// Loads question categories for the Discover tab.
@MainActor
@Observable
final class DiscoverQuestionsViewModel {
    private let supabase: SupabaseManager

    var categories: [QuestionCategory] = []
    var questionCounts: [UUID: Int] = [:]
    var answeredCounts: [UUID: Int] = [:]
    var streakCount = 0
    var isLoading = false

    init(supabase: SupabaseManager = .shared) {
        self.supabase = supabase
    }

    /// Fetches categories and per-category question/answer counts.
    func load(couple: Couple?, currentUserId: UUID?) async {
        guard couple != nil else {
            categories = []
            questionCounts = [:]
            answeredCounts = [:]
            streakCount = 0
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            categories = try await supabase.fetchQuestionCategories()
            streakCount = couple?.questionsStreakCount ?? 0

            var counts: [UUID: Int] = [:]
            var answered: [UUID: Int] = [:]

            let allAnswers = try await supabase.fetchCoupleAnswers(coupleId: couple!.id)

            for category in categories {
                let questions = try await supabase.fetchQuestions(categoryId: category.id)
                counts[category.id] = questions.count
                let questionIds = Set(questions.map(\.id))
                let revealed = allAnswers.filter {
                    questionIds.contains($0.questionId) && $0.isRevealed
                }.count
                answered[category.id] = revealed
            }

            questionCounts = counts
            answeredCounts = answered
        } catch {
            print("🚨 Failed to load question categories: \(error)")
        }
    }
}

/// Loads questions and answers for a single category.
@MainActor
@Observable
final class CategoryQuestionsViewModel {
    private let supabase: SupabaseManager

    let category: QuestionCategory
    var questions: [Question] = []
    var answers: [UUID: CoupleAnswer] = [:]
    var isLoading = false

    private var coupleId: UUID?
    private var currentUserId: UUID?
    nonisolated(unsafe) private var realtimeTask: Task<Void, Never>?

    init(category: QuestionCategory, supabase: SupabaseManager = .shared) {
        self.category = category
        self.supabase = supabase
    }

    deinit {
        realtimeTask?.cancel()
    }

    /// Fetches questions and answer rows for the category.
    func load(couple: Couple?, currentUserId: UUID?) async {
        realtimeTask?.cancel()
        realtimeTask = nil

        guard let couple, let currentUserId else {
            questions = []
            answers = [:]
            return
        }

        coupleId = couple.id
        self.currentUserId = currentUserId
        isLoading = true
        defer { isLoading = false }

        do {
            questions = try await supabase.fetchQuestions(categoryId: category.id)
            let allAnswers = try await supabase.fetchCoupleAnswers(coupleId: couple.id)
            let questionIds = Set(questions.map(\.id))
            answers = Dictionary(
                uniqueKeysWithValues: allAnswers
                    .filter { questionIds.contains($0.questionId) }
                    .map { ($0.questionId, $0) }
            )
            startRealtime(coupleId: couple.id)
        } catch {
            print("🚨 Failed to load category questions: \(error)")
        }
    }

    func revealState(for questionId: UUID) -> AnswerRevealState {
        guard let currentUserId else { return .unanswered }
        guard let answer = answers[questionId] else { return .unanswered }
        if answer.isRevealed { return .revealed }
        if answer.hasAnswered(userId: currentUserId) { return .waiting }
        return .unanswered
    }

    /// Submits an answer and updates local state.
    func submitAnswer(questionId: UUID, text: String) async -> Bool {
        do {
            let updated = try await supabase.submitQuestionAnswer(
                questionId: questionId,
                response: text
            )
            answers[questionId] = updated
            return true
        } catch {
            print("🚨 Failed to submit category answer: \(error)")
            return false
        }
    }

    private func startRealtime(coupleId: UUID) {
        realtimeTask = supabase.listenForCoupleAnswerChanges(coupleId: coupleId) { [weak self] in
            await self?.refreshAnswers()
        }
    }

    private func refreshAnswers() async {
        guard let coupleId else { return }
        do {
            let allAnswers = try await supabase.fetchCoupleAnswers(coupleId: coupleId)
            let questionIds = Set(questions.map(\.id))
            answers = Dictionary(
                uniqueKeysWithValues: allAnswers
                    .filter { questionIds.contains($0.questionId) }
                    .map { ($0.questionId, $0) }
            )
        } catch {
            print("🚨 Failed to refresh category answers: \(error)")
        }
    }
}

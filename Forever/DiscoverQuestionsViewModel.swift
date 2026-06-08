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
    var hasAnsweredAnyCategoryQuestionToday = false

    private var coupleId: UUID?
    private var questionsById: [UUID: Question] = [:]
    private var realtimeObserverToken: UUID?

    init(supabase: SupabaseManager = .shared) {
        self.supabase = supabase
    }

    /// Detaches from the shared couple-answers realtime hub.
    func stopRealtime() async {
        await supabase.stopObservingCoupleAnswerChanges(token: realtimeObserverToken)
        realtimeObserverToken = nil
    }

    /// Fetches categories and per-category question/answer counts.
    func load(couple: Couple?, currentUserId: UUID?) async {
        await stopRealtime()

        guard let couple else {
            categories = []
            questionCounts = [:]
            answeredCounts = [:]
            streakCount = 0
            hasAnsweredAnyCategoryQuestionToday = false
            coupleId = nil
            questionsById = [:]
            return
        }

        coupleId = couple.id
        isLoading = true
        defer { isLoading = false }

        do {
            categories = try await supabase.fetchQuestionCategories()
            streakCount = couple.questionsStreakCount

            let pacingInputs = try await supabase.fetchCategoryPacingInputs(coupleId: couple.id)
            questionsById = Dictionary(uniqueKeysWithValues: pacingInputs.questions.map { ($0.id, $0) })
            hasAnsweredAnyCategoryQuestionToday = CategoryQuestionPacing.hasAnsweredAnyCategoryQuestionToday(
                answers: pacingInputs.answers,
                questionsById: questionsById
            )

            var counts: [UUID: Int] = [:]
            var answered: [UUID: Int] = [:]

            for category in categories {
                let questions = try await supabase.fetchQuestions(categoryId: category.id)
                counts[category.id] = questions.count
                let questionIds = Set(questions.map(\.id))
                let revealed = pacingInputs.answers.filter {
                    questionIds.contains($0.questionId) && $0.isRevealed
                }.count
                answered[category.id] = revealed
            }

            questionCounts = counts
            answeredCounts = answered
            await startRealtime(coupleId: couple.id)
        } catch {
            print("🚨 Failed to load question categories: \(error)")
        }
    }

    private func startRealtime(coupleId: UUID) async {
        realtimeObserverToken = await supabase.observeCoupleAnswerChanges(coupleId: coupleId) { [weak self] in
            await self?.refreshPacing()
        }
    }

    private func refreshPacing() async {
        guard let coupleId else { return }
        do {
            let pacingInputs = try await supabase.fetchCategoryPacingInputs(coupleId: coupleId)
            questionsById = Dictionary(uniqueKeysWithValues: pacingInputs.questions.map { ($0.id, $0) })
            hasAnsweredAnyCategoryQuestionToday = CategoryQuestionPacing.hasAnsweredAnyCategoryQuestionToday(
                answers: pacingInputs.answers,
                questionsById: questionsById
            )

            var answered: [UUID: Int] = [:]
            for category in categories {
                let questions = try await supabase.fetchQuestions(categoryId: category.id)
                let questionIds = Set(questions.map(\.id))
                let revealed = pacingInputs.answers.filter {
                    questionIds.contains($0.questionId) && $0.isRevealed
                }.count
                answered[category.id] = revealed
            }
            answeredCounts = answered
        } catch {
            print("🚨 Failed to refresh category pacing: \(error)")
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
    var hasAnsweredAnyCategoryQuestionToday = false
    var todaysDailyQuestionId: UUID?

    private var coupleId: UUID?
    private var currentUserId: UUID?
    private var questionsById: [UUID: Question] = [:]
    private var realtimeObserverToken: UUID?

    init(category: QuestionCategory, supabase: SupabaseManager = .shared) {
        self.category = category
        self.supabase = supabase
    }

    var isGloballyLocked: Bool { hasAnsweredAnyCategoryQuestionToday }

    var sortedQuestions: [Question] {
        CategoryQuestionPacing.sortedQuestions(questions)
    }

    /// Detaches from the shared couple-answers realtime hub.
    func stopRealtime() async {
        await supabase.stopObservingCoupleAnswerChanges(token: realtimeObserverToken)
        realtimeObserverToken = nil
    }

    /// Fetches questions and answer rows for the category.
    func load(couple: Couple?, currentUserId: UUID?) async {
        await stopRealtime()

        guard let couple, let currentUserId else {
            questions = []
            answers = [:]
            hasAnsweredAnyCategoryQuestionToday = false
            todaysDailyQuestionId = nil
            return
        }

        coupleId = couple.id
        self.currentUserId = currentUserId
        isLoading = true
        defer { isLoading = false }

        do {
            questions = try await supabase.fetchQuestions(categoryId: category.id)
            let pacingInputs = try await supabase.fetchCategoryPacingInputs(coupleId: couple.id)
            questionsById = Dictionary(uniqueKeysWithValues: pacingInputs.questions.map { ($0.id, $0) })
            hasAnsweredAnyCategoryQuestionToday = CategoryQuestionPacing.hasAnsweredAnyCategoryQuestionToday(
                answers: pacingInputs.answers,
                questionsById: questionsById
            )

            let dailyPool = try await supabase.fetchDailyQuestions()
            todaysDailyQuestionId = CategoryQuestionPacing.todaysDailyQuestionId(
                dailyPool: dailyPool,
                coupleId: couple.id
            )

            let questionIds = Set(questions.map(\.id))
            answers = Dictionary(
                uniqueKeysWithValues: pacingInputs.answers
                    .filter { questionIds.contains($0.questionId) }
                    .map { ($0.questionId, $0) }
            )
            await startRealtime(coupleId: couple.id)
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

    /// Whether a question row should be blurred and untappable.
    func isQuestionLocked(_ question: Question) -> Bool {
        CategoryQuestionPacing.isQuestionLocked(
            question: question,
            sortedQuestions: sortedQuestions,
            answers: answers,
            hasAnsweredAnyCategoryQuestionToday: hasAnsweredAnyCategoryQuestionToday,
            todaysDailyQuestionId: todaysDailyQuestionId,
            categoryTitle: category.title
        )
    }

    /// Submits an answer and updates local state.
    func submitAnswer(questionId: UUID, text: String) async -> Bool {
        do {
            let updated = try await supabase.submitQuestionAnswer(
                questionId: questionId,
                response: text
            )
            answers[questionId] = updated
            await refreshAnswers()
            return true
        } catch {
            print("🚨 Failed to submit category answer: \(error)")
            return false
        }
    }

    private func startRealtime(coupleId: UUID) async {
        realtimeObserverToken = await supabase.observeCoupleAnswerChanges(coupleId: coupleId) { [weak self] in
            await self?.refreshAnswers()
        }
    }

    private func refreshAnswers() async {
        guard let coupleId else { return }
        do {
            let pacingInputs = try await supabase.fetchCategoryPacingInputs(coupleId: coupleId)
            questionsById = Dictionary(uniqueKeysWithValues: pacingInputs.questions.map { ($0.id, $0) })
            hasAnsweredAnyCategoryQuestionToday = CategoryQuestionPacing.hasAnsweredAnyCategoryQuestionToday(
                answers: pacingInputs.answers,
                questionsById: questionsById
            )

            let questionIds = Set(questions.map(\.id))
            answers = Dictionary(
                uniqueKeysWithValues: pacingInputs.answers
                    .filter { questionIds.contains($0.questionId) }
                    .map { ($0.questionId, $0) }
            )
        } catch {
            print("🚨 Failed to refresh category answers: \(error)")
        }
    }
}

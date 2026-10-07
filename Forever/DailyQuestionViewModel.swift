import Foundation
import Observation
import os

/// Loads and manages the home-screen daily question and reveal state.
@MainActor
@Observable
final class DailyQuestionViewModel {
    private let supabase: SupabaseManager

    var question: Question?
    var answer: CoupleAnswer?
    var isLoading = false
    var isSubmitting = false
    var errorMessage: String?

    private var coupleId: UUID?
    private var currentUserId: UUID?
    private var realtimeObserverToken: UUID?

    init(supabase: SupabaseManager = .shared) {
        self.supabase = supabase
    }

    /// Detaches from the shared couple-answers realtime hub.
    func stopRealtime() async {
        await supabase.stopObservingCoupleAnswerChanges(token: realtimeObserverToken)
        realtimeObserverToken = nil
    }

    /// Fetches today's question and answer row, then starts Realtime listening.
    func load(couple: Couple?, currentUserId: UUID?) async {
        await stopRealtime()

        guard let couple, let currentUserId else {
            question = nil
            answer = nil
            coupleId = nil
            self.currentUserId = nil
            return
        }

        coupleId = couple.id
        self.currentUserId = currentUserId
        isLoading = true
        defer { isLoading = false }

        do {
            let pool = try await supabase.fetchDailyQuestions()
            question = DailyQuestionSelector.todaysQuestion(from: pool, coupleId: couple.id)
            if let questionId = question?.id {
                answer = try await supabase.fetchCoupleAnswer(
                    coupleId: couple.id,
                    questionId: questionId
                )
            }
            await startRealtime(coupleId: couple.id)
        } catch {
            Log.data.error("Failed to load daily question: \(String(describing: error))")
            errorMessage = error.localizedDescription
        }
    }

    /// Submits the current user's answer and refreshes local state.
    func submitAnswer(_ text: String) async -> Bool {
        guard let questionId = question?.id else { return false }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            answer = try await supabase.submitQuestionAnswer(
                questionId: questionId,
                response: text
            )
            return true
        } catch {
            Log.data.error("Failed to submit answer: \(String(describing: error))")
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Reveal state derived from the current answer row.
    var revealState: AnswerRevealState {
        guard let currentUserId else { return .unanswered }
        guard let answer else { return .unanswered }
        if answer.isRevealed { return .revealed }
        if answer.hasAnswered(userId: currentUserId) { return .waiting }
        return .unanswered
    }

    private func startRealtime(coupleId: UUID) async {
        realtimeObserverToken = await supabase.observeCoupleAnswerChanges(coupleId: coupleId) { [weak self] in
            await self?.refreshAnswer()
        }
    }

    private func refreshAnswer() async {
        guard let coupleId, let questionId = question?.id else { return }
        do {
            answer = try await supabase.fetchCoupleAnswer(
                coupleId: coupleId,
                questionId: questionId
            )
        } catch {
            Log.data.error("Failed to refresh couple answer: \(String(describing: error))")
        }
    }
}

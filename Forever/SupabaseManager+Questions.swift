import Foundation
import os
import Supabase

// Daily and category questions, answers, and the shared answers channel.
extension SupabaseManager {
    /// Fetches all question categories ordered by sort_order.
    func fetchQuestionCategories() async throws -> [QuestionCategory] {
        try await client.from(DB.questionCategories)
            .select()
            .order("sort_order", ascending: true)
            .execute()
            .value
    }

    /// Fetches questions belonging to a category.
    func fetchQuestions(categoryId: UUID) async throws -> [Question] {
        try await client.from(DB.questions)
            .select()
            .eq("category_id", value: categoryId)
            .execute()
            .value
    }

    /// Fetches the pool of daily questions.
    func fetchDailyQuestions() async throws -> [Question] {
        try await client.from(DB.questions)
            .select()
            .eq("is_daily", value: true)
            .execute()
            .value
    }

    /// Fetches the full questions catalog (used for pacing joins).
    func fetchAllQuestions() async throws -> [Question] {
        try await client.from(DB.questions)
            .select()
            .execute()
            .value
    }

    /// Fetches couple answers and the questions catalog for pacing evaluation.
    func fetchCategoryPacingInputs(coupleId: UUID) async throws -> (answers: [CoupleAnswer], questions: [Question]) {
        async let answers = fetchCoupleAnswers(coupleId: coupleId)
        async let questions = fetchAllQuestions()
        return try await (answers, questions)
    }

    /// Fetches the couple's answer row for a specific question, if it exists.
    func fetchCoupleAnswer(coupleId: UUID, questionId: UUID) async throws -> CoupleAnswer? {
        let rows: [CoupleAnswer] = try await client.from(DB.coupleAnswers)
            .select()
            .eq("couple_id", value: coupleId)
            .eq("question_id", value: questionId)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    /// Fetches all answer rows for a couple (used for category progress).
    func fetchCoupleAnswers(coupleId: UUID) async throws -> [CoupleAnswer] {
        try await client.from(DB.coupleAnswers)
            .select()
            .eq("couple_id", value: coupleId)
            .execute()
            .value
    }

    /// Submits the current user's answer via the secure RPC.
    func submitQuestionAnswer(questionId: UUID, response: String) async throws -> CoupleAnswer {
        try await client.rpc(
            "submit_question_answer",
            params: SubmitQuestionAnswerParams(
                p_question_id: questionId,
                p_response: response
            )
        )
        .execute()
        .value
    }
}

// MARK: - Couple Answers Realtime Hub

/// One postgres-change channel per couple, fanning out events to multiple UI observers.
actor CoupleAnswersRealtimeHub {
    private let client: SupabaseClient
    private var observers: [UUID: @MainActor @Sendable () async -> Void] = [:]
    private var listenTask: Task<Void, Never>?
    private var activeCoupleId: UUID?

    init(client: SupabaseClient) {
        self.client = client
    }

    /// Registers `onChange` and starts the shared channel when needed.
    func addObserver(
        coupleId: UUID,
        onChange: @escaping @MainActor @Sendable () async -> Void
    ) -> UUID {
        let token = UUID()
        observers[token] = onChange

        if activeCoupleId != coupleId {
            listenTask?.cancel()
            listenTask = nil
            if let previous = activeCoupleId {
                let oldTopic = Self.topic(for: previous)
                Task { await Self.tearDownChannel(client: client, topic: oldTopic) }
            }
            activeCoupleId = coupleId
        }

        if listenTask == nil {
            listenTask = startListening(coupleId: coupleId)
        }
        return token
    }

    /// Detaches an observer and tears down the channel when none remain.
    func removeObserver(_ token: UUID) async {
        observers.removeValue(forKey: token)
        guard observers.isEmpty else { return }

        listenTask?.cancel()
        listenTask = nil
        if let coupleId = activeCoupleId {
            await Self.tearDownChannel(client: client, topic: Self.topic(for: coupleId))
            activeCoupleId = nil
        }
    }

    private func startListening(coupleId: UUID) -> Task<Void, Never> {
        Task {
            let topic = Self.topic(for: coupleId)
            await Self.tearDownChannel(client: client, topic: topic)
            guard !Task.isCancelled else { return }

            let channel = client.realtimeV2.channel(topic)
            let filter = RealtimePostgresFilter.eq("couple_id", value: coupleId)
            let inserts = channel.postgresChange(
                InsertAction.self, schema: "public", table: DB.coupleAnswers, filter: filter
            )
            let updates = channel.postgresChange(
                UpdateAction.self, schema: "public", table: DB.coupleAnswers, filter: filter
            )

            let consumeTask = Task {
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await _ in inserts {
                            guard !Task.isCancelled else { return }
                            await self.notifyObservers()
                        }
                    }
                    group.addTask {
                        for await _ in updates {
                            guard !Task.isCancelled else { return }
                            await self.notifyObservers()
                        }
                    }
                }
            }

            do {
                try await channel.subscribeWithError()
            } catch {
                consumeTask.cancel()
                Log.realtime.error("Couple answers subscribe failed: \(String(describing: error))")
                await Self.tearDownChannel(client: client, topic: topic)
                return
            }

            await consumeTask.value
            await Self.tearDownChannel(client: client, topic: topic)
        }
    }

    private func notifyObservers() async {
        for callback in observers.values {
            await callback()
        }
    }

    private static func topic(for coupleId: UUID) -> String {
        "couple-answers-\(coupleId.uuidString)"
    }

    private static func tearDownChannel(client: SupabaseClient, topic: String) async {
        let existing = client.realtimeV2.channel(topic)
        await client.realtimeV2.removeChannel(existing)
    }
}

// MARK: - DTOs

private nonisolated struct SubmitQuestionAnswerParams: Encodable, Sendable {
    let p_question_id: UUID
    let p_response: String
}

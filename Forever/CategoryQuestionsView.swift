import SwiftUI

/// Lists questions in a category with answer-to-reveal detail.
struct CategoryQuestionsView: View {
    @Environment(AppStateManager.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let category: QuestionCategory

    @State private var viewModel: CategoryQuestionsViewModel
    @State private var selectedQuestion: Question?

    init(category: QuestionCategory) {
        self.category = category
        _viewModel = State(initialValue: CategoryQuestionsViewModel(category: category))
    }

    private var partnerName: String {
        state.partnerProfile?.displayName ?? String(localized: "Partner")
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.questions.isEmpty {
                ProgressView()
            } else if viewModel.questions.isEmpty {
                ContentUnavailableView(
                    "No Questions",
                    systemImage: "questionmark.circle",
                    description: Text("Questions for this category will appear here.")
                )
            } else {
                List(viewModel.questions) { question in
                    Button {
                        selectedQuestion = question
                    } label: {
                        questionRow(question)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.load(
                couple: state.currentCouple,
                currentUserId: state.currentUser?.id
            )
        }
        .sheet(item: $selectedQuestion) { question in
            questionDetailSheet(question)
        }
    }

    private func questionRow(_ question: Question) -> some View {
        let revealState = viewModel.revealState(for: question.id)

        return HStack(spacing: 12) {
            statusIcon(for: revealState)

            VStack(alignment: .leading, spacing: 4) {
                Text(question.questionText)
                    .font(ForeverFont.body(.body))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(statusLabel(for: revealState))
                    .font(ForeverFont.caption())
                    .foregroundStyle(statusColor(for: revealState))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func questionDetailSheet(_ question: Question) -> some View {
        QuestionDetailSheet(
            question: question,
            partnerName: partnerName,
            viewModel: viewModel,
            userId: state.currentUser?.id,
            reduceMotion: reduceMotion,
            onDismiss: { selectedQuestion = nil }
        )
    }

    private func statusIcon(for state: AnswerRevealState) -> some View {
        Group {
            switch state {
            case .unanswered:
                Image(systemName: "circle")
                    .foregroundStyle(.tertiary)
            case .waiting:
                Image(systemName: "clock.fill")
                    .foregroundStyle(QuestionsTheme.accent)
            case .revealed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(QuestionsTheme.accent)
            }
        }
        .font(.title3)
        .frame(width: 28)
    }

    private func statusLabel(for state: AnswerRevealState) -> String {
        switch state {
        case .unanswered: "Not answered"
        case .waiting: "Waiting for partner"
        case .revealed: "Revealed"
        }
    }

    private func statusColor(for state: AnswerRevealState) -> Color {
        switch state {
        case .unanswered: .secondary
        case .waiting: QuestionsTheme.accent
        case .revealed: QuestionsTheme.accent
        }
    }
}

// MARK: - Detail sheet

private struct QuestionDetailSheet: View {
    let question: Question
    let partnerName: String
    let viewModel: CategoryQuestionsViewModel
    let userId: UUID?
    let reduceMotion: Bool
    let onDismiss: () -> Void

    @State private var showAnswerSheet = false

    private var revealState: AnswerRevealState {
        viewModel.revealState(for: question.id)
    }

    private var answer: CoupleAnswer? {
        viewModel.answers[question.id]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(question.questionText)
                        .font(ForeverFont.header(.title3))
                        .fixedSize(horizontal: false, vertical: true)

                    detailContent
                }
                .padding(20)
            }
            .navigationTitle("Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
            .sheet(isPresented: $showAnswerSheet) {
                QuestionAnswerSheet(
                    questionText: question.questionText,
                    isSubmitting: false,
                    onSubmit: { text in
                        await viewModel.submitAnswer(questionId: question.id, text: text)
                    },
                    onDismiss: { showAnswerSheet = false }
                )
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var detailContent: some View {
        switch revealState {
        case .unanswered:
            Button {
                showAnswerSheet = true
            } label: {
                Text("Answer")
                    .font(ForeverFont.cta(.headline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(QuestionsTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())

        case .waiting:
            VStack(spacing: 12) {
                Label("Waiting for \(partnerName)", systemImage: "checkmark.circle.fill")
                    .font(ForeverFont.subheader(.subheadline))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                    Text("\(partnerName)'s answer is locked until they respond.")
                        .font(ForeverFont.caption())
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

        case .revealed:
            if let userId, let answer {
                HStack(alignment: .top, spacing: 12) {
                    revealedColumn(
                        title: "You",
                        text: answer.myResponse(for: userId) ?? ""
                    )
                    revealedColumn(
                        title: partnerName,
                        text: answer.partnerResponse(for: userId) ?? ""
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .animation(
                    reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82),
                    value: revealState
                )
            }
        }
    }

    private func revealedColumn(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ForeverFont.bold(.caption))
                .foregroundStyle(QuestionsTheme.accent)
            Text(text)
                .font(ForeverFont.body(.subheadline))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(UIColor.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

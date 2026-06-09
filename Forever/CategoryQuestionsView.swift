import SwiftUI

/// Lists questions in a category with answer-to-reveal detail.
struct CategoryQuestionsView: View {
    @Environment(AppStateManager.self) private var state

    let category: QuestionCategory

    @State private var viewModel: CategoryQuestionsViewModel

    init(category: QuestionCategory) {
        self.category = category
        _viewModel = State(initialValue: CategoryQuestionsViewModel(category: category))
    }

    private var partnerName: String {
        state.partnerDisplayName
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
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(viewModel.sortedQuestions) { question in
                            questionRow(question)
                        }
                    }
                    .padding(20)
                    .globalCategoryLockOverlay(isActive: viewModel.isGloballyLocked)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await viewModel.load(
                couple: state.currentCouple,
                currentUserId: state.currentUser?.id
            )
        }
        .onDisappear {
            Task { await viewModel.stopRealtime() }
        }
    }

    @ViewBuilder
    private func questionRow(_ question: Question) -> some View {
        let locked = viewModel.isQuestionLocked(question)

        if locked {
            questionCard(question)
                .questionCardLockOverlay(isLocked: true)
        } else {
            NavigationLink {
                QuestionAnswerView(
                    question: question,
                    partnerName: partnerName,
                    userId: state.currentUser?.id,
                    viewModel: viewModel
                )
            } label: {
                questionCard(question)
            }
            .buttonStyle(.plain)
        }
    }

    private func questionCard(_ question: Question) -> some View {
        let revealState = viewModel.revealState(for: question.id)

        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(question.questionText)
                    .font(ForeverFont.header(.headline))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(statusLabel(for: revealState))
                    .font(ForeverFont.subheader(.subheadline))
                    .foregroundStyle(statusColor(for: revealState))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
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

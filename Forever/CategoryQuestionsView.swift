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
                        ForEach(viewModel.displayOrderedQuestions) { question in
                            questionRow(question)
                        }
                    }
                    .padding(20)
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

                statusSubtitle(for: revealState)
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

    @ViewBuilder
    private func statusSubtitle(for revealState: AnswerRevealState) -> some View {
        switch revealState {
        case .unanswered:
            Text("Not answered")
                .font(ForeverFont.subheader(.subheadline))
                .foregroundStyle(.secondary)
        case .waiting:
            (Text("Waiting for ")
                + Text(partnerName).foregroundStyle(QuestionsTheme.accent))
                .font(ForeverFont.subheader(.subheadline))
                .foregroundStyle(.secondary)
        case .revealed:
            Text("Revealed")
                .font(ForeverFont.subheader(.subheadline))
                .foregroundStyle(QuestionsTheme.accent)
        }
    }
}

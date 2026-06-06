import SwiftUI

/// Questions tab: browse categories and track streak progress.
struct DiscoverQuestionsView: View {
    @Environment(AppStateManager.self) private var state
    @State private var viewModel = DiscoverQuestionsViewModel()
    @State private var showPairingSheet = false

    var body: some View {
        NavigationStack {
            Group {
                if state.currentCouple == nil {
                    unpairedState
                } else if viewModel.isLoading && viewModel.categories.isEmpty {
                    ProgressView()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if viewModel.streakCount > 0 {
                                Text("\(viewModel.streakCount) day streak")
                                    .font(ForeverFont.subheader(.subheadline))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            categoryList
                        }
                        .padding(20)
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Questions")
            .navigationBarTitleDisplayMode(.large)
            .task(id: state.currentCouple?.id) {
                await viewModel.load(
                    couple: state.currentCouple,
                    currentUserId: state.currentUser?.id
                )
            }
            .onChange(of: state.currentCouple?.questionsStreakCount) { _, count in
                viewModel.streakCount = count ?? 0
            }
            .refreshable {
                await viewModel.load(
                    couple: state.currentCouple,
                    currentUserId: state.currentUser?.id
                )
            }
            .sheet(isPresented: $showPairingSheet) {
                PairingView()
                    .environment(state)
            }
        }
    }

    private var categoryList: some View {
        VStack(spacing: 16) {
            ForEach(viewModel.categories) { category in
                NavigationLink {
                    CategoryQuestionsView(category: category)
                } label: {
                    categoryCard(category)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func categoryCard(_ category: QuestionCategory) -> some View {
        let total = viewModel.questionCounts[category.id] ?? 0
        let answered = viewModel.answeredCounts[category.id] ?? 0

        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(category.title)
                    .font(ForeverFont.header(.headline))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                if let description = category.description {
                    Text(description)
                        .font(ForeverFont.subheader(.subheadline))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                if total > 0 {
                    Text("\(answered)/\(total) revealed")
                        .font(ForeverFont.caption())
                        .foregroundStyle(QuestionsTheme.accent)
                }
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

    private var unpairedState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 48))
                .foregroundStyle(.quaternary)
            Text("Pair with your partner")
                .font(ForeverFont.header(.title2))
            Text("Questions are a shared experience — connect with your partner to get started.")
                .font(ForeverFont.body(.body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Connect Partner") {
                showPairingSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(QuestionsTheme.accent)
        }
        .padding()
    }
}

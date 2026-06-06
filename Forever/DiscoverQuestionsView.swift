import SwiftUI

/// Questions tab: browse categories and track streak progress.
struct DiscoverQuestionsView: View {
    @Environment(AppStateManager.self) private var state
    @State private var viewModel = DiscoverQuestionsViewModel()
    @State private var showPairingSheet = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

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

                            categoryGrid
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

    private var categoryGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
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

        return VStack(alignment: .leading, spacing: 8) {
            Text(category.title)
                .font(ForeverFont.header(.headline))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if let description = category.description {
                Text(description)
                    .font(ForeverFont.caption())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            if total > 0 {
                Text("\(answered)/\(total) revealed")
                    .font(ForeverFont.caption())
                    .foregroundStyle(QuestionsTheme.accent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        .padding(16)
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

import SwiftUI

/// Home-screen card for today's question with answer-to-reveal states.
struct DailyQuestionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let questionText: String
    let partnerName: String
    let revealState: AnswerRevealState
    let myAnswer: String?
    let partnerAnswer: String?
    let streakCount: Int
    let onAnswerTapped: () -> Void

    @State private var showRevealedContent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            Text(questionText)
                .font(ForeverFont.header(.headline))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            contentForState
        }
        .padding(20)
        .background(QuestionsTheme.cardFill(colorScheme: colorScheme), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
        .onChange(of: revealState) { _, newState in
            updateRevealAnimation(for: newState)
        }
        .onAppear {
            showRevealedContent = revealState == .revealed
        }
    }

    private var headerRow: some View {
        HStack {
            Label("Daily Topic", systemImage: "bubble.left.and.bubble.right.fill")
                .font(ForeverFont.subheader(.subheadline))
                .foregroundStyle(QuestionsTheme.accent)

            Spacer()

            if streakCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                    Text("\(streakCount)")
                        .font(ForeverFont.bold(.caption))
                }
                .foregroundStyle(QuestionsTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(QuestionsTheme.accent.opacity(0.12), in: Capsule())
            }
        }
    }

    @ViewBuilder
    private var contentForState: some View {
        switch revealState {
        case .unanswered:
            Button(action: onAnswerTapped) {
                Text("Answer")
                    .font(ForeverFont.cta(.headline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(QuestionsTheme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())

        case .waiting:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(QuestionsTheme.accent)
                (Text("You've answered — waiting for ")
                    + Text(partnerName).foregroundStyle(QuestionsTheme.accent))
                    .font(ForeverFont.subheader(.subheadline))
                    .foregroundStyle(.secondary)
            }

        case .revealed:
            if showRevealedContent {
                revealedAnswers
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
    }

    private var revealedAnswers: some View {
        VStack(alignment: .leading, spacing: 12) {
            answerColumn(title: "You", text: myAnswer ?? "")
            answerColumn(title: partnerName, text: partnerAnswer ?? "")
        }
    }

    private func answerColumn(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ForeverFont.bold(.caption))
                .foregroundStyle(QuestionsTheme.accent)
            Text(text)
                .font(ForeverFont.body(.subheadline))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(UIColor.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func updateRevealAnimation(for state: AnswerRevealState) {
        guard state == .revealed else {
            showRevealedContent = false
            return
        }
        if reduceMotion {
            showRevealedContent = true
        } else {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                showRevealedContent = true
            }
        }
    }
}

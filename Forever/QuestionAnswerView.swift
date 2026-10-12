import SwiftUI
import UIKit

/// Full-page question answer flow with onboarding-style input and discard-on-back.
struct QuestionAnswerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppStateManager.self) private var state

    let question: Question
    let partnerName: String
    let userId: UUID?
    var viewModel: CategoryQuestionsViewModel

    @State private var response = ""
    @State private var isSubmitting = false
    @State private var showDiscardAlert = false
    @State private var submitErrorMessage: String?
    @FocusState private var isFocused: Bool

    private var myName: String {
        let name = state.currentUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return "Me" }
        return name
    }

    private var revealState: AnswerRevealState {
        viewModel.revealState(for: question.id)
    }

    private var isSubmissionLocked: Bool {
        revealState == .unanswered && viewModel.isQuestionLocked(question)
    }

    private var answer: CoupleAnswer? {
        viewModel.answers[question.id]
    }

    private var trimmedResponse: String {
        response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasUnsavedDraft: Bool {
        revealState == .unanswered && !trimmedResponse.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: OnboardingLayout.bodyStackSpacing) {
                Text(question.questionText)
                    .font(ForeverFont.header(.title2))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)
                    .padding(.top, 8)

                contentForState
            }
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .background {
            KeyboardDismissTap {
                isFocused = false
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(revealState == .unanswered)
        .toolbar {
            if revealState == .unanswered {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: attemptBack) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                    }
                }
            }
        }
        .confirmationDialog(
            "Leave without submitting?",
            isPresented: $showDiscardAlert,
            titleVisibility: .visible
        ) {
            Button("Discard Answer", role: .destructive) { dismiss() }
            Button("Keep Writing", role: .cancel) {}
        } message: {
            Text("Your progress will be lost if you leave now.")
        }
    }

    @ViewBuilder
    private var contentForState: some View {
        switch revealState {
        case .unanswered:
            unansweredContent
        case .waiting:
            waitingContent
        case .revealed:
            revealedContent
        }
    }

    private var unansweredContent: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            if isSubmissionLocked {
                lockedSubmissionContent
            } else {
                editableSubmissionContent
            }
        }
    }

    private var lockedSubmissionContent: some View {
        Text(QuestionsTheme.dailyUnlockMessage)
            .font(ForeverFont.subheader(.subheadline))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
            .padding(.top, 8)
    }

    private var editableSubmissionContent: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            TextField("Your answer", text: $response, axis: .vertical)
                .font(ForeverFont.body(.title2))
                .multilineTextAlignment(.center)
                .lineLimit(3 ... 8)
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
                .focused($isFocused)
                .submitLabel(.return)

            IntroPrimaryButton(
                title: isSubmitting ? "Submitting..." : "Submit Answer",
                isEnabled: !trimmedResponse.isEmpty && !isSubmitting,
                action: submitAnswer
            )
            .padding(.horizontal, OnboardingLayout.horizontalPadding)

            if let submitErrorMessage {
                Text(submitErrorMessage)
                    .font(ForeverFont.caption())
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            isFocused = true
        }
    }

    private var waitingContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(QuestionsTheme.accent)
            (Text("Waiting for ")
                + Text(partnerName).foregroundStyle(QuestionsTheme.accent))
                .font(ForeverFont.subheader(.subheadline))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
    }

    @ViewBuilder
    private var revealedContent: some View {
        if let userId, let answer {
            VStack(spacing: 16) {
                answerBubble(
                    name: myName,
                    text: answer.myResponse(for: userId) ?? ""
                )
                answerBubble(
                    name: partnerName,
                    text: answer.partnerResponse(for: userId) ?? ""
                )
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .animation(
                reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82),
                value: revealState
            )
        }
    }

    private func answerBubble(name: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(ForeverFont.bold(.caption))
                .foregroundStyle(QuestionsTheme.accent)

            Text(text)
                .font(ForeverFont.body(.title2))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func attemptBack() {
        if hasUnsavedDraft {
            showDiscardAlert = true
        } else {
            dismiss()
        }
    }

    private func submitAnswer() {
        guard !isSubmissionLocked, !trimmedResponse.isEmpty else { return }
        isSubmitting = true
        submitErrorMessage = nil
        Task {
            let success = await viewModel.submitAnswer(questionId: question.id, text: trimmedResponse)
            isSubmitting = false
            if success {
                dismiss()
            } else {
                submitErrorMessage = "Daily category question limit reached."
            }
        }
    }
}

/// Dismisses the keyboard when a tap lands outside a text field or button.
private struct KeyboardDismissTap: UIViewRepresentable {
    var onDismiss: () -> Void

    func makeUIView(context: Context) -> KeyboardDismissInstallView {
        let view = KeyboardDismissInstallView()
        view.isUserInteractionEnabled = false
        view.onWindowChange = { window in
            context.coordinator.install(on: window)
        }
        return view
    }

    func updateUIView(_ uiView: KeyboardDismissInstallView, context: Context) {
        context.coordinator.onDismiss = onDismiss
    }

    static func dismantleUIView(_ uiView: KeyboardDismissInstallView, coordinator: Coordinator) {
        uiView.onWindowChange = nil
        coordinator.install(on: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onDismiss: () -> Void
        private weak var window: UIWindow?
        private var recognizer: UITapGestureRecognizer?

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        /// Installs one tap recognizer on the host window, or removes it when the window goes away.
        func install(on window: UIWindow?) {
            guard self.window !== window else { return }
            if let recognizer, let window = self.window {
                window.removeGestureRecognizer(recognizer)
            }
            recognizer = nil
            self.window = window
            guard let window else { return }

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
            recognizer = tap
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            guard let view = touch.view else { return false }
            return !keepsKeyboard(for: view)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc private func handleTap() {
            onDismiss()
        }

        private func keepsKeyboard(for view: UIView) -> Bool {
            var current: UIView? = view
            while let candidate = current {
                if candidate is UITextField || candidate is UITextView || candidate is UIControl {
                    return true
                }
                current = candidate.superview
            }
            return false
        }
    }
}

private final class KeyboardDismissInstallView: UIView {
    var onWindowChange: ((UIWindow?) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onWindowChange?(window)
    }
}

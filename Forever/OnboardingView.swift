import SwiftUI
import UIKit

/// Funnel order. Creators pay before signing in; the login step saves their local draft afterwards.
enum OnboardingStep: Int, CaseIterable {
    case welcome, problem, solution
    case myName, partnerName
    case anniversary, anniversaryInsight, relationshipGoals, reflection
    case firstMemorySetup, firstMemoryMap, memoryCelebration
    case features
    case reviewAsk
    case journeySummary, upfrontInvestment, commitment, commitmentEncouragement
    case paywall, login

    /// Steps that count toward the onboarding progress bar (paywall and sign-in excluded).
    static var progressTrackedSteps: [OnboardingStep] {
        allCases.filter { $0 != .paywall && $0 != .login }
    }

    static var progressStepCount: Int { progressTrackedSteps.count }
}

enum OnboardingIntroTheme {
    static let accent = Color(red: 1.0, green: 45.0 / 255.0, blue: 85.0 / 255.0)

    private static let lightBackground = Color(
        red: 250.0 / 255.0,
        green: 250.0 / 255.0,
        blue: 250.0 / 255.0
    )

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .black : lightBackground
    }

    static func elevatedSurface(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(UIColor.secondarySystemBackground)
            : Color.white.opacity(0.95)
    }

    static func subtleBorder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }
}

enum OnboardingLayout {
    static let horizontalPadding: CGFloat = 40
    static let titleFont = ForeverFont.header(size: 36, relativeTo: .largeTitle)
    static let bodyStackSpacing: CGFloat = 30
    static let ctaStackSpacing: CGFloat = 12
    static let selectionStackSpacing: CGFloat = 24
    static let selectionRowSpacing: CGFloat = 14
    static let selectionCornerRadius: CGFloat = 20
}

enum RelationshipGoal: String, CaseIterable, Identifiable {
    case feelingCloserEveryDay
    case moreSpontaneousSurprises
    case neverLosingSpark
    case neverForgettingLittleThings
    case cherishMemories
    case alwaysBeingThere

    var id: String { rawValue }

    var text: String {
        switch self {
        case .feelingCloserEveryDay: "Feeling closer every day"
        case .moreSpontaneousSurprises: "More spontaneous surprises"
        case .neverLosingSpark: "Never losing the spark, no matter the distance"
        case .neverForgettingLittleThings: "Never forgetting the little things"
        case .cherishMemories: "Cherish the memories we make"
        case .alwaysBeingThere: "Knowing each other on many levels"
        }
    }

    static let displayOrder: [RelationshipGoal] = [
        .feelingCloserEveryDay,
        .cherishMemories,
        .neverLosingSpark,
        .neverForgettingLittleThings,
        .alwaysBeingThere,
        .moreSpontaneousSurprises
    ]
}

/// Onboarding container: progress bar plus the step router driven by `OnboardingViewModel`.
struct OnboardingView: View {
    @Environment(AppStateManager.self) private var state
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var viewModel = OnboardingViewModel()

    private var standardStepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OnboardingIntroTheme.background(for: colorScheme)
                    .ignoresSafeArea()

                VStack {
                    if viewModel.showsProgress {
                        ProgressView(
                            value: viewModel.progressValue,
                            total: Double(OnboardingStep.progressStepCount)
                        )
                        .progressViewStyle(.linear)
                        .tint(viewModel.isIntroPhase ? OnboardingIntroTheme.accent : .pink)
                        .padding(.horizontal, OnboardingLayout.horizontalPadding)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }

                    stepView
                        .id(viewModel.currentStep)
                        .transition(standardStepTransition)

                    Spacer()
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.currentStep)
        .onAppear {
            viewModel.restoreFlow()
        }
        .onChange(of: viewModel.currentStep) { _, step in
            dismissKeyboard()
            if step == .features { viewModel.featureTab = 0 }
        }
        .onChange(of: viewModel.isComplete) { _, isComplete in
            guard isComplete else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                hasCompletedOnboarding = true
            }
        }
        .alert("Could Not Save Memory", isPresented: Binding(
            get: { viewModel.memoryStageError != nil },
            set: { if !$0 { viewModel.memoryStageError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.memoryStageError ?? "")
        }
    }

    /// Routes the current step to its view.
    @ViewBuilder
    private var stepView: some View {
        switch viewModel.currentStep {
        case .welcome:
            IntroWelcomeView(
                onGetStarted: viewModel.advance,
                onInviteCode: viewModel.startInvitedFlow,
                onSignIn: viewModel.startReturningUserSignIn
            )
        case .problem:
            IntroPromptStepView(
                title: "Do you ever feel like life can sometimes get too busy to truly connect with your partner?",
                cta: "Yes",
                action: viewModel.advance
            )
        case .solution:
            IntroPromptStepView(
                title: "Forever helps you with keeping the spark alive by turning your daily moments into a lasting shared story.",
                cta: "I want that",
                action: viewModel.advance
            )
        case .myName:
            IntroNameInputView(title: "What's your name?", name: bindable.draft.myName, action: viewModel.advance)
        case .partnerName:
            IntroNameInputView(title: "What's your partner's name?", name: bindable.draft.partnerName, action: viewModel.advance)
        case .anniversary:
            IntroAnniversaryPickerView(anniversary: bindable.anniversary, action: viewModel.advance)
        case .anniversaryInsight:
            IntroAnniversaryInsightView(
                myName: viewModel.draft.myName,
                partnerName: viewModel.draft.partnerName,
                anniversary: viewModel.anniversary,
                action: viewModel.advance
            )
        case .relationshipGoals:
            IntroRelationshipGoalsView { goals in
                viewModel.selectedRelationshipGoals = goals
                viewModel.advance()
            }
        case .reflection:
            IntroReflectionView(selectedGoals: viewModel.selectedRelationshipGoals, action: viewModel.advance)
        case .firstMemorySetup:
            IntroPromptStepView(
                title: "Let's start with capturing a memory you want to remember forever.",
                subtitle: "Upload a photo from your gallery and add a quick note to start your shared memory map.",
                cta: "I'm ready",
                action: viewModel.advance
            )
        case .firstMemoryMap:
            IntroOnboardingMapStep(
                showAddMemory: bindable.showAddMemory,
                localMemory: viewModel.memoryPreview,
                onMemoryStaged: { image, note, coordinate in
                    viewModel.stageMemory(image: image, note: note, coordinate: coordinate, appState: state)
                },
                onContinue: viewModel.advance
            )
        case .memoryCelebration:
            IntroMemoryCelebrationView(
                image: viewModel.memoryPreview?.image,
                note: viewModel.memoryPreview?.note,
                coordinate: viewModel.memoryPreview?.coordinate,
                action: viewModel.advance
            )
        case .features:
            IntroFeaturePreviewView(
                tab: bindable.featureTab,
                myName: viewModel.draft.myName,
                partnerName: viewModel.draft.partnerName,
                anniversary: viewModel.anniversary,
                action: viewModel.advance
            )
        case .reviewAsk:
            IntroReviewAskView(action: viewModel.advance)
        case .journeySummary:
            IntroJourneySummaryView(action: viewModel.advance)
        case .upfrontInvestment:
            IntroUpfrontInvestmentView(action: viewModel.advance)
        case .commitment:
            IntroCommitmentView(
                onHighCommitment: viewModel.goToPaywall,
                onLowerCommitment: viewModel.goToCommitmentEncouragement
            )
        case .commitmentEncouragement:
            IntroCommitmentEncouragementView(action: viewModel.goToPaywall)
        case .paywall:
            OnboardingPaywallStep {
                Task { await viewModel.paywallCompleted(appState: state) }
            }
        case .login:
            OnboardingLoginView(
                mode: viewModel.loginMode,
                onSignedIn: { await viewModel.signedIn(appState: state) },
                onBack: viewModel.canCancelSignIn ? { viewModel.cancelSignIn() } : nil
            )
        }
    }

    private var bindable: Bindable<OnboardingViewModel> { Bindable(viewModel) }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

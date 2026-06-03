import SwiftUI
import CoreLocation
import MapKit
import StoreKit
import UIKit
import UserNotifications
import AuthenticationServices

enum OnboardingStep: Int, CaseIterable {
    case welcome, problem, solution
    case myName, partnerName
    case anniversary, anniversaryInsight, relationshipGoals, reflection
    case features
    case firstMemorySetup, firstMemoryMap, memoryCelebration, reviewAsk
    case journeySummary, upfrontInvestment, commitment, commitmentEncouragement
    case intent, login, investment, paywall

    /// Steps that count toward the onboarding progress bar (paywall excluded).
    static var progressTrackedSteps: [OnboardingStep] {
        allCases.filter { $0 != .paywall }
    }

    static var progressStepCount: Int { progressTrackedSteps.count }
}

enum OnboardingIntroTheme {
    static let background = Color(red: 250.0 / 255.0, green: 250.0 / 255.0, blue: 250.0 / 255.0)
    static let accent = Color(red: 1.0, green: 45.0 / 255.0, blue: 85.0 / 255.0)
}

enum OnboardingLayout {
    static let horizontalPadding: CGFloat = 40
    static let titleFont = Font.system(size: 36, weight: .bold, design: .rounded)
    static let bodyStackSpacing: CGFloat = 30
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
        case .alwaysBeingThere: "Always being there for each other"
        }
    }
}

struct OnboardingView: View {
    @Environment(AppStateManager.self) private var state
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("tempMyName") private var myName = ""
    @AppStorage("tempPartnerName") private var partnerName = ""
    @AppStorage("tempAnniversary") private var anniversary = Date().timeIntervalSince1970

    @State private var currentStep: OnboardingStep = .welcome
    @State private var featureTab = 0
    @State private var selectedRelationshipGoals: [RelationshipGoal] = []
    @State private var showOnboardingAddMemory = false
    @State private var localOnboardingMemory: (image: UIImage, note: String, coordinate: CLLocationCoordinate2D)?
    @State private var onboardingMemoryStageError: String?
    @State private var isInvitedPartner = false
    @AppStorage("isInvitedPartner") private var persistedInvitedPartner = false

    private var isInvitedFlow: Bool {
        isInvitedPartner || persistedInvitedPartner
    }

    private var isIntroPhase: Bool {
        currentStep.rawValue <= OnboardingStep.commitmentEncouragement.rawValue
    }

    private var onboardingProgressValue: Double {
        guard let index = OnboardingStep.progressTrackedSteps.firstIndex(of: currentStep) else {
            return Double(OnboardingStep.progressStepCount)
        }
        return Double(index + 1)
    }

    private var standardStepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    var body: some View {
        ZStack {
            if isIntroPhase {
                OnboardingIntroTheme.background
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.04, blue: 0.14).opacity(0.08),
                        Color(UIColor.systemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }

            VStack {
                if currentStep != .paywall && !isInvitedFlow {
                    ProgressView(
                        value: onboardingProgressValue,
                        total: Double(OnboardingStep.progressStepCount)
                    )
                    .progressViewStyle(.linear)
                    .tint(isIntroPhase ? OnboardingIntroTheme.accent : .pink)
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }

                // View Router
                switch currentStep {
                case .welcome:
                    IntroWelcomeView(
                        onGetStarted: advance,
                        onInviteCode: skipToInviteLogin
                    )
                    .transition(standardStepTransition)
                case .problem:
                    IntroPromptStepView(
                        title: "Do you ever feel like life gets too busy to truly connect with your partner?",
                        cta: "Yes",
                        action: advance
                    )
                    .transition(standardStepTransition)
                case .solution:
                    IntroPromptStepView(
                        title: "Forever helps you with keeping the spark alive by turning your daily moments into a lasting shared story.",
                        cta: "I want that",
                        action: advance
                    )
                    .transition(standardStepTransition)
                case .myName:
                    IntroNameInputView(title: "What's your name?", name: $myName, action: advance)
                        .transition(standardStepTransition)
                case .partnerName:
                    IntroNameInputView(title: "What's your partner's name?", name: $partnerName, action: advance)
                        .transition(standardStepTransition)
                case .anniversary:
                    IntroAnniversaryPickerView(
                        anniversary: Binding(
                            get: { Date(timeIntervalSince1970: anniversary) },
                            set: { anniversary = $0.timeIntervalSince1970 }
                        ),
                        action: advance
                    )
                    .transition(standardStepTransition)
                case .anniversaryInsight:
                    IntroAnniversaryInsightView(
                        myName: myName,
                        partnerName: partnerName,
                        anniversary: Date(timeIntervalSince1970: anniversary),
                        action: advance
                    )
                    .transition(standardStepTransition)
                case .relationshipGoals:
                    IntroRelationshipGoalsView { goals in
                        selectedRelationshipGoals = goals
                        advance()
                    }
                    .transition(standardStepTransition)
                case .reflection:
                    IntroReflectionView(
                        selectedGoals: selectedRelationshipGoals,
                        action: advance
                    )
                    .transition(standardStepTransition)
                case .features:
                    IntroFeaturePreviewView(tab: $featureTab, action: advance)
                        .transition(standardStepTransition)
                case .firstMemorySetup:
                    IntroPromptStepView(
                        title: "Let's capture your first memory.",
                        subtitle: "Upload a favorite photo and add a quick note. We'll drop it on the map to start your shared journey.",
                        cta: "Ready",
                        action: advance
                    )
                    .transition(standardStepTransition)
                case .firstMemoryMap:
                    IntroOnboardingMapStep(
                        showAddMemory: $showOnboardingAddMemory,
                        localMemory: $localOnboardingMemory,
                        onMemoryStaged: stageOnboardingMemoryFromSheet,
                        onContinue: advance
                    )
                    .transition(standardStepTransition)
                case .memoryCelebration:
                    IntroMemoryCelebrationView(
                        image: localOnboardingMemory?.image,
                        note: localOnboardingMemory?.note,
                        coordinate: localOnboardingMemory?.coordinate,
                        action: advance
                    )
                    .transition(standardStepTransition)
                case .reviewAsk:
                    IntroReviewAskView(action: advance)
                        .transition(standardStepTransition)
                case .journeySummary:
                    IntroJourneySummaryView(action: advance)
                        .transition(standardStepTransition)
                case .upfrontInvestment:
                    IntroUpfrontInvestmentView(action: advance)
                        .transition(standardStepTransition)
                case .commitment:
                    IntroCommitmentView(
                        onHighCommitment: goToPaywall,
                        onLowerCommitment: goToCommitmentEncouragement
                    )
                    .transition(standardStepTransition)
                case .commitmentEncouragement:
                    IntroCommitmentEncouragementView(action: goToPaywall)
                        .transition(standardStepTransition)
                case .intent:
                    IntentSelectionView(action: advance)
                        .transition(standardStepTransition)
                case .login:
                    OnboardingLoginView(
                        isInvitedPartner: isInvitedFlow,
                        action: advance,
                        onAuthenticated: syncOnboardingMemoryAfterAuth,
                        onInvitedPartnerComplete: completeInvitedPartnerOnboarding
                    )
                    .transition(standardStepTransition)
                case .investment:
                    OnboardingInvestmentView(onContinue: advance)
                        .transition(standardStepTransition)
                case .paywall:
                    OnboardingPaywallStep {
                        completeOnboarding()
                    }
                    .transition(standardStepTransition)
                }

                Spacer()
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
        .onAppear {
            if persistedInvitedPartner, currentStep.rawValue < OnboardingStep.login.rawValue {
                isInvitedPartner = true
                currentStep = .login
            }
        }
        .onChange(of: currentStep) { _, step in
            if step == .features {
                featureTab = 0
            }
        }
        .alert(
            "Could Not Save Memory",
            isPresented: Binding(
                get: { onboardingMemoryStageError != nil },
                set: { if !$0 { onboardingMemoryStageError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(onboardingMemoryStageError ?? "")
        }
    }

    private func advance() {
        resignFirstResponder()
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    private func resignFirstResponder() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    /// Skips onboarding funnel and routes invited partners straight to Sign-In.
    private func skipToInviteLogin() {
        resignFirstResponder()
        isInvitedPartner = true
        persistedInvitedPartner = true
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep = .login
        }
    }

    /// Ends onboarding for invited partners after Apple Sign-In (pairing next).
    private func completeInvitedPartnerOnboarding() {
        persistedInvitedPartner = false
        isInvitedPartner = false
        withAnimation(.easeInOut(duration: 0.5)) {
            hasCompletedOnboarding = true
        }
    }

    private func goToPaywall() {
        resignFirstResponder()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep = .paywall
        }
    }

    private func goToCommitmentEncouragement() {
        resignFirstResponder()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentStep = .commitmentEncouragement
        }
    }

    /// Stages the first memory locally from AddMemoryView; map step stays until Continue.
    private func stageOnboardingMemoryFromSheet(
        image: UIImage,
        note: String,
        location: CLLocationCoordinate2D
    ) {
        do {
            localOnboardingMemory = (image, note, location)
            try state.stageOnboardingMemory(image: image, note: note, coordinate: location)
            showOnboardingAddMemory = false
        } catch {
            onboardingMemoryStageError = error.localizedDescription
            print("🚨 Stage onboarding memory error: \(error)")
        }
    }

    /// Uploads the staged onboarding memory after Apple Sign-In, then clears local UI state.
    private func syncOnboardingMemoryAfterAuth() async {
        guard localOnboardingMemory != nil || state.hasPendingOnboardingMemory else { return }

        var synced = await state.flushPendingOnboardingMemory()

        if !synced, let local = localOnboardingMemory, state.currentUser != nil {
            synced = await state.flushOnboardingMemory(
                image: local.image,
                note: local.note,
                coordinate: local.coordinate
            )
        }

        if synced {
            await MainActor.run {
                localOnboardingMemory = nil
            }
        }
    }

    /// Persists the user's onboarding details to Supabase, refreshes global state, then dismisses onboarding.
    private func completeOnboarding() {
        Task {
            let anniversaryDate = Date(timeIntervalSince1970: anniversary)

            // Push details to Supabase (partnerName remains local until they pair)
            try? await SupabaseManager.shared.updateProfileDetails(name: myName, anniversary: anniversaryDate)

            // Refresh state so SettingsView fetches the updated currentUser
            await state.initializeApp()
            await syncOnboardingMemoryAfterAuth()

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}

// MARK: - Subviews

struct IntroPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isEnabled ? OnboardingIntroTheme.accent : Color.gray)
                .cornerRadius(16)
        }
        .buttonStyle(BubblyButtonStyle())
        .disabled(!isEnabled)
    }
}

struct IntroWelcomeView: View {
    let onGetStarted: () -> Void
    let onInviteCode: () -> Void
    @State private var titleVisible = false

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            Spacer()
            Text("Welcome to Forever.")
                .font(OnboardingLayout.titleFont)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .opacity(titleVisible ? 1 : 0)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
            Spacer()

            IntroPrimaryButton(title: "Get Started", action: onGetStarted)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

            Button(action: onInviteCode) {
                Text("I have an invite code")
                    .font(.headline)
                    .foregroundStyle(OnboardingIntroTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(OnboardingIntroTheme.accent.opacity(0.6), lineWidth: 1.5)
                    )
            }
            .buttonStyle(BubblyButtonStyle())
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
            .padding(.bottom, 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7)) {
                titleVisible = true
            }
        }
    }
}

struct IntroPromptStepView: View {
    let title: String
    var subtitle: String? = nil
    let cta: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            Text(title)
                .font(OnboardingLayout.titleFont)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

            if let subtitle {
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)
            }

            Spacer()

            IntroPrimaryButton(title: cta, action: action)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
        }
    }
}

struct NameInputView: View {
    let title: String
    @Binding var name: String
    let action: () -> Void
    
    // THE FIX: Native SwiftUI Focus State
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 30) {
            Text(title)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            TextField("First Name", text: $name)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
                .padding(.horizontal, 40)
                .focused($isFocused) // Bind focus state
                .submitLabel(.continue) // Changes "Return" key to "Continue"
                .onSubmit { // Allows user to just hit the keyboard button to advance!
                    if !name.isEmpty { action() }
                }

            Button(action: action) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(name.isEmpty ? Color.gray : Color.pink)
                    .cornerRadius(16)
            }
            .disabled(name.isEmpty)
            .padding(.horizontal, 40)
        }
        .onAppear {
            // 0.5s delay guarantees the lateral slide animation finishes BEFORE the keyboard fires up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
    }
}

/// Name entry styled for the intro onboarding phase.
struct IntroNameInputView: View {
    let title: String
    @Binding var name: String
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            Text(title)
                .font(OnboardingLayout.titleFont)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

            TextField("First Name", text: $name)
                .font(.title2)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.white.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
                .focused($isFocused)
                .submitLabel(.continue)
                .onSubmit {
                    if !name.isEmpty { action() }
                }

            Spacer()

            IntroPrimaryButton(title: "Continue", isEnabled: !name.isEmpty, action: action)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isFocused = true
            }
        }
    }
}

struct IntroAnniversaryPickerView: View {
    @Binding var anniversary: Date
    let action: () -> Void

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            Text("When is your anniversary?")
                .font(OnboardingLayout.titleFont)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

            DatePicker("", selection: $anniversary, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(OnboardingIntroTheme.accent)
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(24)
                .padding(.horizontal, 20)

            IntroPrimaryButton(title: "Select", action: action)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
        }
    }
}

struct IntroAnniversaryInsightView: View {
    let myName: String
    let partnerName: String
    let anniversary: Date
    let action: () -> Void

    private var daysTogether: Int {
        max(0, Calendar.current.dateComponents([.day], from: anniversary, to: Date()).day ?? 0)
    }

    private var displayMyName: String {
        let trimmed = myName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "You" }
        return trimmed.prefix(1).uppercased() + trimmed.dropFirst()
    }

    private var displayPartnerName: String {
        let trimmed = partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "your partner" }
        return trimmed.prefix(1).uppercased() + trimmed.dropFirst()
    }

    private var headerText: String {
        "\(displayMyName), you've been making memories with \(displayPartnerName) for \(daysTogether) days. Let's make sure you never forget the next ones."
    }

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            VStack(spacing: 12) {
                Text(headerText)
                    .font(OnboardingLayout.titleFont)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Do you have just 5 minutes a day to stay connected?")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)

            Spacer()

            IntroPrimaryButton(title: "Yes, of course", action: action)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
        }
    }
}

struct IntroRelationshipGoalsView: View {
    @State private var selected: [RelationshipGoal] = []
    let action: ([RelationshipGoal]) -> Void

    private let maxSelections = 3

    var body: some View {
        VStack(spacing: OnboardingLayout.selectionStackSpacing) {
            Text("What does a thriving relationship look like to you?")
                .font(OnboardingLayout.titleFont)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

            Text("Choose up to three")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            ScrollView(showsIndicators: false) {
                VStack(spacing: OnboardingLayout.selectionRowSpacing) {
                    ForEach(RelationshipGoal.allCases) { goal in
                        let isSelected = selected.contains(goal)
                        let isDisabled = selected.count >= maxSelections && !isSelected

                        Button {
                            toggle(goal)
                        } label: {
                            IntroSelectableOptionRow(
                                title: goal.text,
                                isSelected: isSelected
                            )
                            .opacity(isDisabled ? 0.45 : 1)
                        }
                        .buttonStyle(BubblyButtonStyle())
                        .disabled(isDisabled)
                    }
                }
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
                .padding(.vertical, 4)
            }

            IntroPrimaryButton(
                title: "Continue",
                isEnabled: !selected.isEmpty
            ) {
                action(selected)
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
        }
    }

    private func toggle(_ goal: RelationshipGoal) {
        if let index = selected.firstIndex(of: goal) {
            selected.remove(at: index)
            return
        }
        guard selected.count < maxSelections else { return }
        selected.append(goal)
    }
}

struct IntroOnboardingMapStep: View {
    @Environment(AppStateManager.self) private var state
    @Binding var showAddMemory: Bool
    @Binding var localMemory: (image: UIImage, note: String, coordinate: CLLocationCoordinate2D)?
    let onMemoryStaged: (UIImage, String, CLLocationCoordinate2D) -> Void
    let onContinue: () -> Void

    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var mapCenterCoordinate = CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)

    private var mapCard: some View {
        Map(position: $mapPosition) {
            if let memory = localMemory {
                Annotation("", coordinate: memory.coordinate) {
                    MemoryMapPinLabel(image: memory.image, note: memory.note)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                mapCard

                if localMemory == nil {
                    VStack(spacing: 10) {
                        BouncingTooltip(accentColor: OnboardingIntroTheme.accent)
                        MemoryMapFABButton(accent: OnboardingIntroTheme.accent) {
                            showAddMemory = true
                        }
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if localMemory != nil {
                IntroPrimaryButton(title: "Continue", action: onContinue)
            }
        }
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .sheet(isPresented: $showAddMemory) {
            AddMemoryView(
                onboardingSaveAction: onMemoryStaged,
                initialCoordinate: mapCenterCoordinate
            )
            .environment(state)
        }
        .task {
            AmbientDataManager.shared.requestLocationAuthorizationFirst()
            let center = await AmbientDataManager.shared.mapCenterCoordinate()
            mapCenterCoordinate = center
            mapPosition = .region(
                MKCoordinateRegion(
                    center: center,
                    latitudinalMeters: 8_000,
                    longitudinalMeters: 8_000
                )
            )
        }
        .onChange(of: showAddMemory) { wasShowing, isShowing in
            guard wasShowing, !isShowing, let coordinate = localMemory?.coordinate else { return }
            focusMap(on: coordinate)
        }
    }

    /// Animates the map camera to the staged memory coordinate.
    private func focusMap(on coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 1.2)) {
            mapPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 5_000,
                    longitudinalMeters: 5_000
                )
            )
        }
    }
}

/// Non-interactive mini-map preview for the celebration step.
private struct IntroMemoryMapPreviewCard: View {
    let image: UIImage
    let note: String
    let coordinate: CLLocationCoordinate2D

    @State private var mapPosition: MapCameraPosition = .automatic

    private let cardWidth: CGFloat = 180
    private let cardHeight: CGFloat = 140

    var body: some View {
        Map(position: $mapPosition) {
            Annotation("", coordinate: coordinate) {
                MemoryMapPinLabel(image: image, note: note)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .allowsHitTesting(false)
        .mapControlVisibility(.hidden)
        .onAppear {
            mapPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    latitudinalMeters: 5_000,
                    longitudinalMeters: 5_000
                )
            )
        }
    }
}

struct IntroMemoryCelebrationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var image: UIImage?
    var note: String?
    var coordinate: CLLocationCoordinate2D?
    let action: () -> Void

    @State private var cardVisible = false

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            Spacer(minLength: 12)

            mapPreviewCard
                .scaleEffect(cardVisible ? 1 : 0.92)
                .opacity(cardVisible ? 1 : 0)
                .padding(.bottom, 8)

            Text("First memory secured!")
                .font(OnboardingLayout.titleFont)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

            Text("Your map is officially started. Your partner is going to love this.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

            Spacer()

            IntroPrimaryButton(title: "Continue", action: action)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
        }
        .onAppear {
            if reduceMotion {
                cardVisible = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    cardVisible = true
                }
            }
        }
    }

    @ViewBuilder
    private var mapPreviewCard: some View {
        Group {
            if let image, let coordinate {
                IntroMemoryMapPreviewCard(
                    image: image,
                    note: note ?? "",
                    coordinate: coordinate
                )
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 180, height: 140)
                    .overlay {
                        Image(systemName: "map")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .padding(8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}

struct IntroReviewAskView: View {
    @Environment(\.requestReview) private var requestReview
    let action: () -> Void

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            Text("Having fun so far?")
                .font(OnboardingLayout.titleFont)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

            Text("It would mean the world to us if you left a quick rating. It helps more couples find Forever.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

            Spacer()

            IntroPrimaryButton(title: "Next", action: action)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
        }
        .onAppear {
            requestReview()
        }
    }
}

struct IntroReflectionView: View {
    let selectedGoals: [RelationshipGoal]
    let action: () -> Void

    private var reflectionText: String {
        let labels = selectedGoals.map(\.text)
        let goalText = ListFormatter.localizedString(byJoining: labels)
        if goalText.isEmpty {
            return "We hear you. Forever is designed to help you build your ideal relationship reality, together."
        }
        return "We hear you. You want \(goalText). Forever is designed to help you build that exact reality, together."
    }

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            Text(reflectionText)
                .font(OnboardingLayout.titleFont)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

            Spacer()

            IntroPrimaryButton(title: "Continue", action: action)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
        }
    }
}

struct IntentSelectionView: View {
    @AppStorage("userIntent") private var storedIntent = ""
    @State private var selectedIntent: IntentOption?

    let action: () -> Void

    enum IntentOption: String, CaseIterable, Identifiable {
        case exploring, widgets, ldr, story, location, bond

        var id: String { rawValue }

        var text: String {
            switch self {
            case .exploring: "Just exploring"
            case .widgets: "Use couples widgets"
            case .ldr: "Stay close in long-distance"
            case .story: "Record our love story"
            case .location: "Know my partner's location"
            case .bond: "Deepen our bond"
            }
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("What brings you here?")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    ForEach(IntentOption.allCases) { option in
                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                selectedIntent = option
                            }
                        } label: {
                            Text(option.text)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(
                                        selectedIntent == option
                                            ? Color.pink.opacity(0.08)
                                            : Color(UIColor.secondarySystemBackground)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(selectedIntent == option ? Color.pink : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(BubblyButtonStyle())
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 4)
            }

            Button {
                if let selectedIntent {
                    storedIntent = selectedIntent.rawValue
                }
                action()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedIntent == nil ? Color.gray : Color.pink)
                    .cornerRadius(16)
            }
            .disabled(selectedIntent == nil)
            .padding(.horizontal, 40)
        }
        .onAppear {
            selectedIntent = IntentOption(rawValue: storedIntent)
        }
    }
}

/// Intro-phase preview of Live Distance and Handwritten Notes (no permission prompts).
struct IntroFeaturePreviewView: View {
    @Binding var tab: Int
    let action: () -> Void

    var body: some View {
        TabView(selection: $tab) {
            FeaturePage(
                icon: "location.fill",
                title: "Live Distance",
                description: "See exactly how far apart you are directly on your Lock Screen.",
                buttonTitle: "Next",
                usesIntroStyle: true,
                buttonAction: { withAnimation { tab = 1 } }
            )
            .tag(0)

            FeaturePage(
                icon: "applepencil",
                title: "Handwritten Notes",
                description: "Draw notes that instantly appear on your partner's home screen.",
                buttonTitle: "Continue",
                usesIntroStyle: true,
                buttonAction: action
            )
            .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

struct FeaturePage: View {
    let icon: String
    let title: String
    let description: String
    let buttonTitle: String
    var usesIntroStyle: Bool = false
    let buttonAction: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 100))
                .foregroundStyle(
                    LinearGradient(
                        colors: usesIntroStyle
                            ? [OnboardingIntroTheme.accent, OnboardingIntroTheme.accent.opacity(0.7)]
                            : [.pink, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, 20)

            Text(title)
                .font(usesIntroStyle ? OnboardingLayout.titleFont : .system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal, usesIntroStyle ? OnboardingLayout.horizontalPadding : 0)

            Text(description)
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

            Spacer()

            Group {
                if usesIntroStyle {
                    IntroPrimaryButton(title: buttonTitle, action: buttonAction)
                        .padding(.horizontal, OnboardingLayout.horizontalPadding)
                } else {
                    Button(action: buttonAction) {
                        Text(buttonTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.pink)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 40)
                }
            }
            .padding(.bottom, 60)
        }
    }
}

/// Onboarding paywall: custom 3-step flow with skip path for free tier.
struct OnboardingPaywallStep: View {
    @Environment(SubscriptionManager.self) private var subscription
    let onContinue: () -> Void

    var body: some View {
        ForeverCustomPaywallFlow(
            onCompleted: onContinue,
            onSkip: onContinue
        )
        .onChange(of: subscription.isPro) { _, isPro in
            if isPro { onContinue() }
        }
    }
}

struct OnboardingLoginView: View {
    var isInvitedPartner = false
    let action: () -> Void
    var onAuthenticated: (() async -> Void)?
    var onInvitedPartnerComplete: (() -> Void)?
    @Environment(AppStateManager.self) private var state
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var currentNonce: String?
    @State private var authErrorMessage: String?
    @State private var isLoggingIn = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 100))
                .foregroundStyle(
                    LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .padding(.bottom, 20)
            
            Text("Save Your Profile")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            
            Text("Create your account securely so you and your partner can sync your memories.")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            if isLoggingIn {
                ProgressView().padding()
            }
            
            SignInWithAppleButton(
                onRequest: { request in
                    let nonce = AppleAuthHelper.randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleAuthHelper.sha256(nonce)
                },
                onCompletion: { result in
                    handleAppleAuth(result: result)
                }
            )
            // THE FIX: Adapts the button color perfectly to Light or Dark mode
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
            .disabled(isLoggingIn)
        }
        .onAppear {
            if state.currentUser != nil {
                Task {
                    await finishLoginAfterAuth()
                }
            }
        }
        .alert("Sign In Failed", isPresented: Binding(
            get: { authErrorMessage != nil },
            set: { if !$0 { authErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authErrorMessage ?? "Something went wrong.")
        }
    }
    
    private func handleAppleAuth(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
               let nonce = currentNonce,
               let appleIDToken = appleIDCredential.identityToken,
               let idTokenString = String(data: appleIDToken, encoding: .utf8) {
                
                isLoggingIn = true
                Task {
                    do {
                        try await SupabaseManager.shared.signInWithApple(idToken: idTokenString, nonce: nonce)
                        await state.initializeApp()
                        await finishLoginAfterAuth()
                        await MainActor.run {
                            isLoggingIn = false
                        }
                    } catch {
                        DispatchQueue.main.async {
                            isLoggingIn = false
                            authErrorMessage = "Could not sign in right now. Please try again."
                        }
                    }
                }
            } else {
                authErrorMessage = "Apple Sign In did not return valid credentials."
            }
        case .failure(let error):
            authErrorMessage = "Apple Sign In was cancelled or failed. Please try again."
            print("Authorization failed: \(error)")
        }
    }

    /// Invited partners skip memory upload and paywall; standard flow continues to investment.
    private func finishLoginAfterAuth() async {
        if isInvitedPartner {
            await MainActor.run {
                onInvitedPartnerComplete?()
            }
            return
        }
        await onAuthenticated?()
        await MainActor.run {
            action()
        }
    }
}

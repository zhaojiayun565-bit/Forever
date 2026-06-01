import SwiftUI
import CoreLocation
import MapKit
import PhotosUI
import StoreKit
import UserNotifications
import AuthenticationServices

enum OnboardingStep: Int, CaseIterable {
    case welcome, problem, solution, anniversary, anniversaryInsight, relationshipGoals, reflection
    case firstMemory, memoryCelebration, reviewAsk
    case myName, partnerName, intent, features, login, investment, paywall
}

private enum OnboardingIntroTheme {
    static let background = Color(red: 250.0 / 255.0, green: 250.0 / 255.0, blue: 250.0 / 255.0)
    static let accent = Color(red: 1.0, green: 45.0 / 255.0, blue: 85.0 / 255.0)
}

private enum OnboardingLayout {
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
    @State private var onboardingMemoryImage: UIImage?
    @State private var onboardingMemoryNote = ""
    @State private var onboardingMemoryCoordinate: CLLocationCoordinate2D?

    private var isIntroPhase: Bool {
        currentStep.rawValue <= OnboardingStep.reviewAsk.rawValue
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
                ProgressView(
                    value: Double(currentStep.rawValue + 1),
                    total: Double(OnboardingStep.allCases.count)
                )
                .progressViewStyle(.linear)
                .tint(isIntroPhase ? OnboardingIntroTheme.accent : .pink)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
                .padding(.top, 20)
                .padding(.bottom, 40)

                // View Router
                switch currentStep {
                case .welcome:
                    IntroWelcomeView(action: advance)
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
                case .firstMemory:
                    IntroFirstMemoryView(
                        note: $onboardingMemoryNote,
                        selectedImage: $onboardingMemoryImage,
                        mapCoordinate: $onboardingMemoryCoordinate,
                        onSave: saveOnboardingMemoryAndAdvance
                    )
                    .transition(standardStepTransition)
                case .memoryCelebration:
                    IntroMemoryCelebrationView(action: advance)
                        .transition(standardStepTransition)
                case .reviewAsk:
                    IntroReviewAskView(action: advance)
                        .transition(standardStepTransition)
                case .myName:
                    NameInputView(title: "What's your name?", name: $myName, action: advance)
                        .transition(standardStepTransition)
                case .partnerName:
                    NameInputView(title: "What's your partner's name?", name: $partnerName, action: advance)
                        .transition(standardStepTransition)
                case .intent:
                    IntentSelectionView(action: advance)
                        .transition(standardStepTransition)
                case .features:
                    FeatureCarouselView(tab: $featureTab, action: advance)
                        .transition(standardStepTransition)
                case .login:
                    OnboardingLoginView(action: advance)
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
    }

    private func advance() {
        // Explicitly dismiss the keyboard to ensure smooth transitions to non-text screens
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    /// Stages the first memory locally, then advances to celebration.
    private func saveOnboardingMemoryAndAdvance() async {
        guard let image = onboardingMemoryImage else { return }
        let coordinate = onboardingMemoryCoordinate ?? CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
        do {
            try state.stageOnboardingMemory(image: image, note: onboardingMemoryNote, coordinate: coordinate)
            await MainActor.run {
                advance()
            }
        } catch {
            print("🚨 Stage onboarding memory error: \(error)")
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
            await state.flushPendingOnboardingMemory()

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let action: () -> Void
    @State private var titleVisible = false
    @State private var hasAdvanced = false

    var body: some View {
        VStack {
            Spacer()
            Text("Welcome to Forever.")
                .font(OnboardingLayout.titleFont)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .opacity(titleVisible ? 1 : 0)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            advanceOnce()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7)) {
                titleVisible = true
            }
            let delay = reduceMotion ? 1.2 : 2.0
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                advanceOnce()
            }
        }
    }

    private func advanceOnce() {
        guard !hasAdvanced else { return }
        hasAdvanced = true
        action()
    }
}

struct IntroPromptStepView: View {
    let title: String
    let cta: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            Text(title)
                .font(OnboardingLayout.titleFont)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

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
    let anniversary: Date
    let action: () -> Void

    private var daysTogether: Int {
        max(0, Calendar.current.dateComponents([.day], from: anniversary, to: Date()).day ?? 0)
    }

    private var insightText: String {
        "You've been making memories for \(daysTogether) days. Let's make sure you never forget the next ones. Do you have just 5 minutes a day to stay connected?"
    }

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            Text(insightText)
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
                            HStack(spacing: 12) {
                                Text(goal.text)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(OnboardingIntroTheme.accent)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: OnboardingLayout.selectionCornerRadius, style: .continuous)
                                    .fill(
                                        isSelected
                                            ? OnboardingIntroTheme.accent.opacity(0.1)
                                            : Color.white.opacity(0.95)
                                    )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: OnboardingLayout.selectionCornerRadius, style: .continuous)
                                    .stroke(
                                        isSelected ? OnboardingIntroTheme.accent : Color.clear,
                                        lineWidth: 2
                                    )
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

struct IntroFirstMemoryView: View {
    @Binding var note: String
    @Binding var selectedImage: UIImage?
    @Binding var mapCoordinate: CLLocationCoordinate2D?

    let onSave: () async -> Void

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var pinVisible = false
    @State private var isSaving = false

    private var displayCoordinate: CLLocationCoordinate2D {
        mapCoordinate ?? CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: OnboardingLayout.bodyStackSpacing) {
                        Text("Let's capture your first memory.")
                            .font(OnboardingLayout.titleFont)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Upload a favorite photo and add a quick note. We'll drop it on the map to start your shared journey.")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)

                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 1, matching: .images) {
                            Group {
                                if let selectedImage {
                                    Image(uiImage: selectedImage)
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.on.rectangle.angled")
                                            .font(.system(size: 28, weight: .semibold))
                                        Text("Add Photo")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .foregroundStyle(OnboardingIntroTheme.accent)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(
                                selectedImage == nil
                                    ? OnboardingIntroTheme.accent.opacity(0.08)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(
                                        selectedImage == nil ? OnboardingIntroTheme.accent.opacity(0.35) : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                        }
                        .buttonStyle(BubblyButtonStyle())
                        .onChange(of: selectedItems) { _, items in
                            Task { await loadPhoto(from: items.first) }
                        }

                        TextField("Our first trip to...", text: $note, axis: .vertical)
                            .lineLimit(2 ... 4)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)
                    .padding(.bottom, 12)
                }
                .frame(height: geometry.size.height * 0.48)

                ZStack(alignment: .bottom) {
                    Map(position: $mapPosition) {
                        if pinVisible {
                            Annotation("", coordinate: displayCoordinate) {
                                Group {
                                    if let selectedImage {
                                        Image(uiImage: selectedImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 52, height: 52)
                                            .clipShape(Circle())
                                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                    } else {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 44))
                                            .foregroundStyle(OnboardingIntroTheme.accent)
                                    }
                                }
                                .scaleEffect(pinVisible ? 1 : 0.2)
                                .opacity(pinVisible ? 1 : 0)
                                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)
                    .allowsHitTesting(false)

                    IntroPrimaryButton(
                        title: "Save Memory",
                        isEnabled: selectedImage != nil && !isSaving
                    ) {
                        Task {
                            isSaving = true
                            await onSave()
                            isSaving = false
                        }
                    }
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)
                    .padding(.bottom, 8)
                }
                .frame(height: geometry.size.height * 0.52)
            }
        }
        .overlay {
            if isSaving {
                ProgressView()
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .task {
            AmbientDataManager.shared.requestLocationAuthorizationFirst()
            let center = await AmbientDataManager.shared.mapCenterCoordinate()
            mapCoordinate = center
            mapPosition = .region(
                MKCoordinateRegion(
                    center: center,
                    latitudinalMeters: 8_000,
                    longitudinalMeters: 8_000
                )
            )
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await MainActor.run {
            selectedImage = image
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                pinVisible = true
            }
        }
    }
}

struct IntroMemoryCelebrationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let action: () -> Void

    @State private var showHeart = false
    @State private var animateHero = false

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            Spacer(minLength: 12)

            Group {
                if reduceMotion {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 88))
                        .foregroundStyle(OnboardingIntroTheme.accent)
                } else {
                    Image(systemName: showHeart ? "heart.fill" : "map.fill")
                        .font(.system(size: 88))
                        .foregroundStyle(OnboardingIntroTheme.accent)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.bounce, value: animateHero)
                }
            }
            .padding(.bottom, 8)

            Text("First memory secured! 🔥")
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
            guard !reduceMotion else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    showHeart = true
                }
                animateHero = true
            }
        }
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

struct FeatureCarouselView: View {
    @Binding var tab: Int
    let action: () -> Void

    var body: some View {
        VStack {
            TabView(selection: $tab) {
                // Feature 1: Map
                FeaturePage(
                    icon: "map.fill",
                    title: "Memories Map",
                    description: "Drop photos on an interactive map and build a timeline of your relationship.",
                    buttonTitle: "Next",
                    buttonAction: { withAnimation { tab = 1 } }
                ).tag(0)

                // Feature 2: Location Widget
                FeaturePage(
                    icon: "location.fill",
                    title: "Live Distance",
                    description: "See exactly how far apart you are directly on your Lock Screen.",
                    buttonTitle: "Enable Location",
                    buttonAction: {
                        AmbientDataManager.shared.requestLocationAuthorizationFirst()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation { tab = 2 }
                        }
                    }
                ).tag(1)

                // Feature 3: Drawing Widget
                FeaturePage(
                    icon: "applepencil",
                    title: "Handwritten Notes",
                    description: "Draw notes that instantly appear on your partner's home screen.",
                    buttonTitle: "Enable Notifications",
                    buttonAction: {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                            DispatchQueue.main.async {
                                if granted { UIApplication.shared.registerForRemoteNotifications() }
                                action()
                            }
                        }
                    }
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }
}

struct FeaturePage: View {
    let icon: String
    let title: String
    let description: String
    let buttonTitle: String
    let buttonAction: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 100))
                .foregroundStyle(
                    LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .padding(.bottom, 20)

            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))

            Text(description)
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

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
            .padding(.bottom, 60)
        }
    }
}

/// Onboarding paywall: RevenueCat UI with skip path for free tier.
struct OnboardingPaywallStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForeverPaywallView(
                onCompleted: onContinue,
                onDismiss: onContinue
            )

            Button("Continue without Pro") {
                onContinue()
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.vertical, 12)
        }
    }
}

struct OnboardingLoginView: View {
    let action: () -> Void
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
            // If they close the app and reopen it, skip this step if they are already logged in!
            if state.currentUser != nil {
                Task {
                    await state.flushPendingOnboardingMemory()
                    action()
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
                        await state.flushPendingOnboardingMemory()

                        // Successfully logged in! Smoothly advance to the paywall.
                        DispatchQueue.main.async {
                            isLoggingIn = false
                            action()
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
}

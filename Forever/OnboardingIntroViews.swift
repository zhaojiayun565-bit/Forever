import CoreLocation
import MapKit
import StoreKit
import SwiftUI
import UIKit
import UserNotifications

struct IntroPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ForeverFont.cta(.headline))
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
    let onSignIn: () -> Void
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

            VStack(spacing: OnboardingLayout.ctaStackSpacing) {
                IntroPrimaryButton(title: "Get Started", action: onGetStarted)

                Button(action: onInviteCode) {
                    Text("I have an invite code")
                        .font(ForeverFont.cta(.headline))
                        .foregroundStyle(OnboardingIntroTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(OnboardingIntroTheme.accent.opacity(0.6), lineWidth: 1.5)
                        )
                }
                .buttonStyle(BubblyButtonStyle())

                Button("I already have an account", action: onSignIn)
                    .font(ForeverFont.subheader(.subheadline))
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
            }
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
                    .font(ForeverFont.subheader(.title3))
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

struct IntroNameInputView: View {
    let title: String
    @Binding var name: String
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            Text(title)
                .font(OnboardingLayout.titleFont)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

            TextField("First Name", text: $name)
                .font(ForeverFont.body(.title2))
                .multilineTextAlignment(.center)
                .padding()
                .background(OnboardingIntroTheme.elevatedSurface(for: colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(OnboardingIntroTheme.subtleBorder(for: colorScheme), lineWidth: 1)
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

    @Environment(\.colorScheme) private var colorScheme

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
                .background(OnboardingIntroTheme.elevatedSurface(for: colorScheme))
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
                    .font(ForeverFont.subheader(.title3))
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
                .font(ForeverFont.subheader(.subheadline))
                .foregroundStyle(.secondary)

            ScrollView(showsIndicators: false) {
                VStack(spacing: OnboardingLayout.selectionRowSpacing) {
                    ForEach(RelationshipGoal.displayOrder) { goal in
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
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showAddMemory: Bool
    let localMemory: OnboardingMemoryPreview?
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
                .stroke(OnboardingIntroTheme.subtleBorder(for: colorScheme), lineWidth: 1)
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
    @Environment(\.colorScheme) private var colorScheme
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

            Text("Your memory map has officially started!")
                .font(OnboardingLayout.titleFont)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

            Text("Your partner is going to love creating more memories together on this shared map.")
                .font(ForeverFont.subheader(.title3))
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
                            .font(ForeverFont.header(.title))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .padding(8)
        .background(OnboardingIntroTheme.elevatedSurface(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}

struct IntroReviewAskView: View {
    @Environment(\.requestReview) private var requestReview
    let action: () -> Void

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            Text("Let's help other couples find Forever?")
                .font(OnboardingLayout.titleFont)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

            Text("It would mean the world to us if you left a quick rating. It helps more couples find Forever.")
                .font(ForeverFont.subheader(.title3))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

            Spacer()

            IntroPrimaryButton(title: "Of course") {
                requestReview()
                action()
            }
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
        }
    }
}

/// Displays selected relationship goals as a slightly tilted stack.
private struct IntroTiltedSelectedGoalsStack: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let goals: [RelationshipGoal]

    private static let tiltAngles: [Double] = [-2.5, 2, -1.5, 2.5, -2, 1.5]
    private let tiltedCardSpacing: CGFloat = 20

    var body: some View {
        VStack(spacing: tiltedCardSpacing) {
            ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                IntroSelectableOptionRow(title: goal.text, isSelected: true)
                    .rotationEffect(.degrees(tiltAngle(for: index)))
                    .zIndex(Double(index))
            }
        }
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.vertical, 8)
    }

    /// Single selection stays straight; multiple cards get alternating tilt.
    private func tiltAngle(for index: Int) -> Double {
        guard goals.count > 1, !reduceMotion else { return 0 }
        return Self.tiltAngles[index % Self.tiltAngles.count]
    }
}

struct IntroReflectionView: View {
    let selectedGoals: [RelationshipGoal]
    let action: () -> Void

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            IntroTiltedSelectedGoalsStack(goals: selectedGoals)

            Spacer()

            VStack(spacing: 12) {
                Text("We hear you, many couples want this too.")
                    .font(OnboardingLayout.titleFont)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("Forever is designed to help you build that exact reality together.")
                    .font(ForeverFont.subheader(.title3))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)

            IntroPrimaryButton(title: "Continue", action: action)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
        }
    }
}

/// Intro-phase widget carousel (no permission prompts).
struct IntroFeaturePreviewView: View {
    @Binding var tab: Int
    let myName: String
    let partnerName: String
    let anniversary: Date
    let action: () -> Void

    private var myInitial: String { ForeverMonogramBubble.initial(from: myName) }
    private var partnerInitial: String { ForeverMonogramBubble.initial(from: partnerName) }

    private var displayPartnerName: String {
        let trimmed = partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "your partner" }
        return trimmed.prefix(1).uppercased() + trimmed.dropFirst()
    }

    var body: some View {
        TabView(selection: $tab) {
            FeaturePage(
                icon: "heart.fill",
                title: "Give \(displayPartnerName) a reason to smile every time they unlock their phone.",
                description: "Forever's premium widgets are designed to cut through the daily noise and keep you deeply connected.",
                buttonTitle: "Continue",
                usesIntroStyle: true,
                showsDefaultIcon: false,
                buttonAction: { withAnimation { tab = 1 } }
            ) {
                EmptyView()
            }
            .tag(0)

            FeaturePage(
                icon: "location.fill",
                title: "Live Distance",
                description: "See how far apart you are right on your Lock Screen.",
                buttonTitle: "Continue",
                usesIntroStyle: true,
                showsDefaultIcon: false,
                buttonAction: { withAnimation { tab = 2 } }
            ) {
                LiveDistanceWidgetPreviewCard(
                    myInitial: myInitial,
                    partnerInitial: partnerInitial
                )
            }
            .tag(1)

            FeaturePage(
                icon: "applepencil",
                title: "Handwritten Notes",
                description: "Draw notes that instantly appear on your partner's home screen.",
                buttonTitle: "Continue",
                usesIntroStyle: true,
                showsDefaultIcon: false,
                buttonAction: { withAnimation { tab = 3 } }
            ) {
                HandwrittenNotesWidgetPreviewCard()
            }
            .tag(2)

            FeaturePage(
                icon: "heart.text.square.fill",
                title: "Love Messages",
                description: "Send each other short love messages directly to each other's lockscreen.",
                buttonTitle: "Continue",
                usesIntroStyle: true,
                showsDefaultIcon: false,
                buttonAction: { withAnimation { tab = 4 } }
            ) {
                LoveMessagesWidgetPreviewCard()
            }
            .tag(3)

            FeaturePage(
                icon: "heart.fill",
                title: "Days Together",
                description: "Feel closer everyday as this number goes up.",
                buttonTitle: "Continue",
                usesIntroStyle: true,
                showsDefaultIcon: false,
                buttonAction: action
            ) {
                DaysTogetherWidgetPreviewCard(
                    myName: myName,
                    partnerName: partnerName,
                    anniversary: anniversary
                )
            }
            .tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

struct FeaturePage<Illustration: View>: View {
    let icon: String
    let title: String
    let description: String?
    let buttonTitle: String
    var usesIntroStyle: Bool = false
    var showsDefaultIcon: Bool = true
    let buttonAction: () -> Void
    @ViewBuilder var illustration: () -> Illustration

    init(
        icon: String,
        title: String,
        description: String? = nil,
        buttonTitle: String,
        usesIntroStyle: Bool = false,
        showsDefaultIcon: Bool = true,
        buttonAction: @escaping () -> Void,
        @ViewBuilder illustration: @escaping () -> Illustration
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.buttonTitle = buttonTitle
        self.usesIntroStyle = usesIntroStyle
        self.showsDefaultIcon = showsDefaultIcon
        self.buttonAction = buttonAction
        self.illustration = illustration
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            heroContent

            Text(title)
                .font(usesIntroStyle ? OnboardingLayout.titleFont : ForeverFont.header(size: 32, relativeTo: .title))
                .multilineTextAlignment(.center)
                .padding(.horizontal, usesIntroStyle ? OnboardingLayout.horizontalPadding : 0)

            if let description, !description.isEmpty {
                Text(description)
                    .font(ForeverFont.subheader(.title3))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, OnboardingLayout.horizontalPadding)
            }

            Spacer()

            Group {
                if usesIntroStyle {
                    IntroPrimaryButton(title: buttonTitle, action: buttonAction)
                        .padding(.horizontal, OnboardingLayout.horizontalPadding)
                } else {
                    Button(action: buttonAction) {
                        Text(buttonTitle)
                            .font(ForeverFont.cta(.headline))
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

    @ViewBuilder
    private var heroContent: some View {
        if showsDefaultIcon {
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
        } else {
            illustration()
                .padding(.bottom, 20)
        }
    }
}

extension FeaturePage where Illustration == EmptyView {
    init(
        icon: String,
        title: String,
        description: String? = nil,
        buttonTitle: String,
        usesIntroStyle: Bool = false,
        buttonAction: @escaping () -> Void
    ) {
        self.init(
            icon: icon,
            title: title,
            description: description,
            buttonTitle: buttonTitle,
            usesIntroStyle: usesIntroStyle,
            showsDefaultIcon: true,
            buttonAction: buttonAction,
            illustration: { EmptyView() }
        )
    }
}

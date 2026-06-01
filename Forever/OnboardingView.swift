import SwiftUI
import CoreLocation
import UserNotifications
import AuthenticationServices

enum OnboardingStep: Int, CaseIterable {
    case myName, partnerName, anniversary, intent, features, login, investment, paywall
}

struct OnboardingView: View {
    @Environment(AppStateManager.self) private var state
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("tempMyName") private var myName = ""
    @AppStorage("tempPartnerName") private var partnerName = ""
    @AppStorage("tempAnniversary") private var anniversary = Date().timeIntervalSince1970

    @State private var currentStep: OnboardingStep = .myName
    @State private var featureTab = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.04, blue: 0.14).opacity(0.08),
                    Color(UIColor.systemBackground)
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack {
                // Dynamic Progress Bar
                ProgressView(value: Double(currentStep.rawValue + 1), total: Double(OnboardingStep.allCases.count))
                    .progressViewStyle(.linear)
                    .tint(.pink)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    .padding(.bottom, 40) // THE FIX: Replaces the top Spacer() to permanently top-align the content!

                // View Router
                switch currentStep {
                case .myName:
                    NameInputView(title: "What's your name?", name: $myName, action: advance)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .partnerName:
                    NameInputView(title: "What's your partner's name?", name: $partnerName, action: advance)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .anniversary:
                    AnniversaryInputView(anniversary: Binding(
                        get: { Date(timeIntervalSince1970: anniversary) },
                        set: { anniversary = $0.timeIntervalSince1970 }
                    ), action: advance)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .intent:
                    IntentSelectionView(action: advance)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .features:
                    FeatureCarouselView(tab: $featureTab, action: advance)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .login:
                    OnboardingLoginView(action: advance)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .investment:
                    OnboardingInvestmentView(onContinue: advance)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .paywall:
                    OnboardingPaywallStep {
                        completeOnboarding()
                    }
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
                }
                
                Spacer() // Keep the bottom spacer to push everything firmly to the top
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

    /// Persists the user's onboarding details to Supabase, refreshes global state, then dismisses onboarding.
    private func completeOnboarding() {
        Task {
            let anniversaryDate = Date(timeIntervalSince1970: anniversary)

            // Push details to Supabase (partnerName remains local until they pair)
            try? await SupabaseManager.shared.updateProfileDetails(name: myName, anniversary: anniversaryDate)

            // Refresh state so SettingsView fetches the updated currentUser
            await state.initializeApp()

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    hasCompletedOnboarding = true
                }
            }
        }
    }
}

// MARK: - Subviews

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

struct AnniversaryInputView: View {
    @Binding var anniversary: Date
    let action: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Text("When is your anniversary?")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            DatePicker("", selection: $anniversary, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(.pink)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(24)
                .padding(.horizontal, 20)

            Button(action: action) {
                Text("Continue")
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
                action()
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

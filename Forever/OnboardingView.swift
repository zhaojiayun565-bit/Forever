import SwiftUI
import CoreLocation
import UserNotifications

enum OnboardingStep: Int, CaseIterable {
    case myName, partnerName, anniversary, features, paywall
}

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("tempMyName") private var myName = ""
    @AppStorage("tempPartnerName") private var partnerName = ""
    @AppStorage("tempAnniversary") private var anniversary = Date().timeIntervalSince1970

    @State private var currentStep: OnboardingStep = .myName
    @State private var featureTab = 0

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            VStack {
                // Dynamic Progress Bar
                ProgressView(value: Double(currentStep.rawValue + 1), total: Double(OnboardingStep.allCases.count))
                    .progressViewStyle(.linear)
                    .tint(.pink)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)

                Spacer()

                // View Router with smooth lateral transitions
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
                case .features:
                    FeatureCarouselView(tab: $featureTab, action: advance)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .paywall:
                    PaywallView {
                        completeOnboarding()
                    }
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
                }

                Spacer()
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentStep)
    }

    private func advance() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    private func completeOnboarding() {
        withAnimation(.easeInOut(duration: 0.5)) {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Subviews

struct NameInputView: View {
    let title: String
    @Binding var name: String
    let action: () -> Void

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
                        // Use the unified Singleton
                        AmbientDataManager.shared.requestAlwaysAuthorizationFirst()

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
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                            DispatchQueue.main.async { action() }
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

struct PaywallView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.fill")
                .font(.system(size: 80))
                .foregroundStyle(.pink)
                .shadow(color: .pink.opacity(0.5), radius: 20, x: 0, y: 10)

            Text("Forever Premium")
                .font(.system(size: 36, weight: .black, design: .rounded))

            VStack(alignment: .leading, spacing: 16) {
                PaywallFeatureRow(text: "Unlimited Map Memories")
                PaywallFeatureRow(text: "All Lock Screen Widgets")
                PaywallFeatureRow(text: "Custom Drawing Colors")
                PaywallFeatureRow(text: "Priority Syncing")
            }
            .padding(.vertical, 20)

            Spacer()

            Text("3 Days Free, then $4.99/month")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: onDismiss) {
                Text("Start Free Trial")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(20)
                    .shadow(color: .pink.opacity(0.3), radius: 10, y: 5)
            }
            .padding(.horizontal, 30)

            Button(action: onDismiss) { // For now, dismisses. Will link to RevenueCat later.
                Text("Restore Purchases")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 20)
        }
    }
}

struct PaywallFeatureRow: View {
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.pink)
            Text(text)
                .font(.headline)
        }
    }
}

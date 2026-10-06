import AuthenticationServices
import SwiftUI

/// Onboarding paywall: custom 3-step hard paywall flow.
struct OnboardingPaywallStep: View {
    @Environment(SubscriptionManager.self) private var subscription
    let onContinue: () -> Void

    var body: some View {
        ForeverCustomPaywallFlow(onCompleted: onContinue)
            .onChange(of: subscription.isPro) { _, isPro in
                if isPro { onContinue() }
            }
    }
}

/// Sign-in step: saves the creator's local onboarding draft after the paywall, or starts invite pairing.
struct OnboardingLoginView: View {
    var mode: OnboardingLoginMode = .saveProfile
    let onSignedIn: () async -> Void
    var onBack: (() -> Void)?

    @Environment(AppStateManager.self) private var state
    @Environment(\.colorScheme) private var colorScheme
    @State private var isSigningIn = false

    private var title: String {
        switch mode {
        case .saveProfile: "Save Your Profile"
        case .invitedPartner: "Join Your Partner"
        case .returningUser: "Welcome Back"
        }
    }

    private var subtitle: String {
        switch mode {
        case .saveProfile:
            "Create your account so your profile, first memory, and subscription are saved and can sync with your partner."
        case .invitedPartner:
            "Sign in to connect with your partner using their invite code."
        case .returningUser:
            "Sign in with the Apple Account you used before to pick up where you left off."
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 100))
                .foregroundStyle(
                    LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .padding(.bottom, 20)
                .accessibilityHidden(true)

            Text(title)
                .font(ForeverFont.header(size: 32, relativeTo: .title))

            Text(subtitle)
                .font(ForeverFont.subheader(.title3))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            if isSigningIn {
                ProgressView().padding()
            }

            AppleSignInButton(
                style: colorScheme == .dark ? .white : .black,
                cornerRadius: 16,
                isSigningIn: $isSigningIn,
                onSignedIn: onSignedIn
            )
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .toolbar {
            if let onBack {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onBack) {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
        }
        .task(id: state.currentUser?.id) {
            if state.currentUser != nil {
                await onSignedIn()
            }
        }
    }
}

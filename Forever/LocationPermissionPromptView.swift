import SwiftUI

/// Explains why Forever wants location before the system prompt appears (shown once, after pairing).
struct LocationPermissionPromptView: View {
    let partnerName: String
    let onAllow: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "location.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 96, height: 96)
                .background(OnboardingIntroTheme.accent, in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("See how far apart you are")
                    .font(ForeverFont.header(size: 30, relativeTo: .title))
                    .multilineTextAlignment(.center)

                Text("Share your location with \(partnerName) to show the distance between you on your map and widgets. Only \(partnerName) can see it, and you can turn it off anytime in Settings.")
                    .font(ForeverFont.subheader(.body))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)

            Spacer()

            VStack(spacing: 12) {
                IntroPrimaryButton(title: "Share My Location", action: onAllow)

                Button("Not Now", action: onNotNow)
                    .font(ForeverFont.cta(.headline))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .padding(.bottom, 16)
        .interactiveDismissDisabled()
    }
}

#Preview {
    LocationPermissionPromptView(partnerName: "Alex", onAllow: {}, onNotNow: {})
}

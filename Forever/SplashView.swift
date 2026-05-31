import SwiftUI

// MARK: - Splash

/// Minimal branded launch moment — atmosphere, logo, app name, then fade into the app.
struct SplashView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onComplete: () -> Void

    @State private var phase: SplashPhase = .start
    @State private var glowPulse = false
    @State private var exitTrigger = false

    private let logoGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.55, blue: 0.72),
            Color(red: 0.95, green: 0.35, blue: 0.55),
            Color(red: 0.72, green: 0.32, blue: 0.82)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        ZStack {
            SplashBackground(glowPulse: glowPulse, phase: phase)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "heart.fill")
                    .font(.system(size: 112, weight: .regular))
                    .foregroundStyle(logoGradient)
                    .shadow(color: .pink.opacity(0.35), radius: 28, y: 12)
                    .scaleEffect(phase >= .logo ? 1 : 0.88)
                    .opacity(phase >= .logo ? 1 : 0)
                    .blur(radius: phase >= .logo ? 0 : 6)

                Spacer()
                    .frame(height: 72)

                Text("Forever")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.65, blue: 0.78),
                                Color(red: 0.95, green: 0.45, blue: 0.62)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(phase >= .name ? 1 : 0)
                    .offset(y: phase >= .name ? 0 : 10)

                Spacer()
                    .frame(minHeight: 120)
            }
        }
        .scaleEffect(exitTrigger ? 1.03 : 1)
        .opacity(exitTrigger ? 0 : 1)
        .task { await runSequence() }
    }

    /// Orchestrates the staged reveal, then hands off to the main app.
    private func runSequence() async {
        if reduceMotion {
            phase = .name
            glowPulse = true
            try? await Task.sleep(for: .milliseconds(800))
            await finish()
            return
        }

        withAnimation(.smooth(duration: 1.0)) {
            phase = .atmosphere
            glowPulse = true
        }
        try? await Task.sleep(for: .milliseconds(450))

        withAnimation(.spring(duration: 0.85, bounce: 0.22)) {
            phase = .logo
        }
        try? await Task.sleep(for: .milliseconds(650))

        withAnimation(.spring(duration: 0.75, bounce: 0.18)) {
            phase = .name
        }
        try? await Task.sleep(for: .milliseconds(900))

        await finish()
    }

    private func finish() async {
        await MainActor.run {
            withAnimation(.smooth(duration: 0.55)) {
                exitTrigger = true
            }
        }
        try? await Task.sleep(for: .milliseconds(520))
        await MainActor.run {
            onComplete()
        }
    }
}

// MARK: - Phases

private enum SplashPhase: Int, Comparable {
    case start = 0
    case atmosphere
    case logo
    case name

    static func < (lhs: SplashPhase, rhs: SplashPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Background

private struct SplashBackground: View {
    let glowPulse: Bool
    let phase: SplashPhase

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.04, blue: 0.14),
                    Color(red: 0.12, green: 0.06, blue: 0.22),
                    Color(red: 0.28, green: 0.10, blue: 0.24)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.45, blue: 0.62).opacity(glowPulse ? 0.45 : 0.18),
                    Color(red: 0.85, green: 0.35, blue: 0.55).opacity(0.12),
                    .clear
                ],
                center: .init(x: 0.5, y: 0.92),
                startRadius: 10,
                endRadius: glowPulse ? 340 : 260
            )
            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: glowPulse)

            LinearGradient(
                colors: [.black.opacity(0.35), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .opacity(phase >= .atmosphere ? 1 : 0.6)
        .animation(.smooth(duration: 1.0), value: phase)
    }
}

#Preview {
    SplashView(onComplete: {})
}

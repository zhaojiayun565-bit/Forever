import SwiftUI

// MARK: - Commitment level

enum CommitmentLevel: String, CaseIterable, Identifiable {
    case extremelyCommitted
    case veryCommitted
    case somewhatCommitted
    case aLittleCommitted
    case justTrying

    var id: String { rawValue }

    var label: String {
        switch self {
        case .extremelyCommitted: "Extremely Committed"
        case .veryCommitted: "Very committed"
        case .somewhatCommitted: "Somewhat committed"
        case .aLittleCommitted: "A Little Committed"
        case .justTrying: "Just trying it out"
        }
    }

    var isHighCommitment: Bool {
        switch self {
        case .extremelyCommitted, .veryCommitted: true
        default: false
        }
    }
}

// MARK: - Shared selection row

struct IntroSelectableOptionRow: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(ForeverFont.header(.headline))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                        isSelected ? OnboardingIntroTheme.accent : Color.black.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
    }
}

// MARK: - Journey checklist

private enum JourneyChecklistState {
    case completed
    case current
}

private struct IntroJourneyChecklistRow: View {
    let title: String
    let state: JourneyChecklistState
    let showsConnectorBelow: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                indicator
                if showsConnectorBelow {
                    Rectangle()
                        .fill(Color.black.opacity(0.08))
                        .frame(width: 2, height: 28)
                }
            }
            .frame(width: 28)

            Text(title)
                .font(ForeverFont.header(.headline))
                .foregroundStyle(state == .current ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var indicator: some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(OnboardingIntroTheme.accent.opacity(0.55))
        case .current:
            Circle()
                .strokeBorder(OnboardingIntroTheme.accent, lineWidth: 2.5)
                .background(Circle().fill(OnboardingIntroTheme.accent.opacity(0.12)))
                .frame(width: 28, height: 28)
                .overlay {
                    Circle()
                        .fill(OnboardingIntroTheme.accent)
                        .frame(width: 10, height: 10)
                }
        }
    }
}

// MARK: - Step 11: Journey summary

struct IntroJourneySummaryView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            VStack(spacing: 12) {
                Text("Your journey with your partner starts now.")
                    .font(OnboardingLayout.titleFont)
                    .multilineTextAlignment(.center)

                Text("You are 30 days away from building a completely new habit of connection.")
                    .font(ForeverFont.subheader(.title3))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    IntroJourneyChecklistRow(
                        title: "Set relationship goals",
                        state: .completed,
                        showsConnectorBelow: true
                    )
                    IntroJourneyChecklistRow(
                        title: "Created first memory",
                        state: .completed,
                        showsConnectorBelow: true
                    )
                    IntroJourneyChecklistRow(
                        title: "Build a lasting daily connection",
                        state: .current,
                        showsConnectorBelow: false
                    )
                }
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
                .padding(.vertical, 8)
            }

            IntroPrimaryButton(title: "Continue", action: action)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
        }
    }
}

// MARK: - Step 12: Upfront investment

struct IntroUpfrontInvestmentView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            VStack(spacing: 12) {
                Text("A stronger relationship costs less than one coffee a month.")
                    .font(OnboardingLayout.titleFont)
                    .multilineTextAlignment(.center)

                Text("Forever is a premium experience designed to keep you and your partner close, free from ads and distractions.")
                    .font(ForeverFont.subheader(.title3))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)

            Spacer(minLength: 8)

            HStack(spacing: 16) {
                comparisonCard(
                    icon: {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                    },
                    caption: "1 Coffee / month"
                )

                comparisonCard(
                    icon: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white)
                                .frame(width: 56, height: 56)
                                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                            Image(systemName: "heart.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(OnboardingIntroTheme.accent)
                        }
                    },
                    caption: "A lifetime of memories"
                )
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)

            Spacer(minLength: 8)

            IntroPrimaryButton(title: "Makes sense", action: action)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
        }
    }

    private func comparisonCard<Icon: View>(
        @ViewBuilder icon: () -> Icon,
        caption: String
    ) -> some View {
        VStack(spacing: 14) {
            icon()
            Text(caption)
                .font(ForeverFont.subheader(.subheadline))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: OnboardingLayout.selectionCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: OnboardingLayout.selectionCornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
    }
}

// MARK: - Step 13: Commitment

struct IntroCommitmentView: View {
    @AppStorage("onboardingCommitmentLevel") private var storedCommitmentLevel = ""

    let onHighCommitment: () -> Void
    let onLowerCommitment: () -> Void

    @State private var selectedLevel: CommitmentLevel?

    var body: some View {
        VStack(spacing: OnboardingLayout.selectionStackSpacing) {
            Text("So, how committed are you to making this future happen?")
                .font(OnboardingLayout.titleFont)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)

            ScrollView(showsIndicators: false) {
                VStack(spacing: OnboardingLayout.selectionRowSpacing) {
                    ForEach(CommitmentLevel.allCases) { level in
                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                selectedLevel = level
                            }
                        } label: {
                            IntroSelectableOptionRow(
                                title: level.label,
                                isSelected: selectedLevel == level
                            )
                        }
                        .buttonStyle(BubblyButtonStyle())
                    }
                }
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
                .padding(.vertical, 4)
            }

            IntroPrimaryButton(
                title: "Continue",
                isEnabled: selectedLevel != nil
            ) {
                continueTapped()
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
        }
    }

    private func continueTapped() {
        guard let selectedLevel else { return }
        storedCommitmentLevel = selectedLevel.rawValue

        if selectedLevel.isHighCommitment {
            onHighCommitment()
        } else {
            onLowerCommitment()
        }
    }
}

// MARK: - Encouragement (low commitment branch)

struct IntroCommitmentEncouragementView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: OnboardingLayout.bodyStackSpacing) {
            Spacer(minLength: 12)

            VStack(spacing: 12) {
                Text("That's okay! Every great relationship starts with small steps.")
                    .font(OnboardingLayout.titleFont)
                    .multilineTextAlignment(.center)

                Text("Let's take the first one together.")
                    .font(ForeverFont.subheader(.title3))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, OnboardingLayout.horizontalPadding)

            Spacer()

            IntroPrimaryButton(title: "Let's do it", action: action)
                .padding(.horizontal, OnboardingLayout.horizontalPadding)
        }
    }
}

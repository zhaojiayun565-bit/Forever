import SwiftUI

// MARK: - Configuration

struct LiveDistanceClosingAnimationConfiguration {
    var startDistanceKm: Int = 250
    var animationDuration: TimeInterval = 4
    var togetherPauseDuration: TimeInterval = 1.8
    var resetDuration: TimeInterval = 0.4
    var resetPauseDuration: TimeInterval = 0.6
    var avatarSize: CGFloat = 52
    var heartWidth: CGFloat = 14
    var minConnectorGap: CGFloat = 2
}

// MARK: - View Model

@Observable
final class LiveDistanceClosingAnimationViewModel {
    var animationProgress: CGFloat = 0

    let configuration: LiveDistanceClosingAnimationConfiguration

    private var loopTask: Task<Void, Never>?

    init(configuration: LiveDistanceClosingAnimationConfiguration = .init()) {
        self.configuration = configuration
    }

    static let togetherMessage = "We're together!"

    /// Continuous distance value tied to animation progress for Animatable interpolation.
    var animatedDistanceKm: Double {
        Double(configuration.startDistanceKm) * Double(1 - animationProgress)
    }

    var isTogether: Bool {
        animatedDistanceKm <= 0
    }

    /// Maps progress to the half-gap between each avatar and the center heart.
    func connectorHalfGap(totalWidth: CGFloat, horizontalPadding: CGFloat) -> CGFloat {
        let usableWidth = totalWidth - horizontalPadding * 2
        let occupiedByAvatars = configuration.avatarSize * 2 + configuration.heartWidth
        let maxGap = max((usableWidth - occupiedByAvatars) / 2, configuration.minConnectorGap)
        let minGap = configuration.minConnectorGap
        return maxGap - (maxGap - minGap) * animationProgress
    }

    func startLoop(reduceMotion: Bool) {
        stopLoop()

        if reduceMotion {
            animationProgress = 1
            return
        }

        loopTask = Task { @MainActor in
            while !Task.isCancelled {
                animationProgress = 0

                withAnimation(.easeInOut(duration: configuration.animationDuration)) {
                    animationProgress = 1
                }

                try? await Task.sleep(for: .seconds(configuration.animationDuration))

                guard !Task.isCancelled else { return }

                try? await Task.sleep(for: .seconds(configuration.togetherPauseDuration))

                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: configuration.resetDuration)) {
                    animationProgress = 0
                }

                try? await Task.sleep(for: .seconds(configuration.resetDuration + configuration.resetPauseDuration))
            }
        }
    }

    func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
    }
}

// MARK: - Distance Counter

/// Smoothly interpolates the displayed km value by animating progress via animatableData.
struct DistanceCounter: View, Animatable {
    var progress: CGFloat
    var startDistanceKm: Double
    var togetherMessage: String

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    private var distanceKm: Double {
        startDistanceKm * Double(1 - progress)
    }

    var body: some View {
        HStack(spacing: 4) {
            if distanceKm > 0 {
                Text("Our distance:")
                    .font(ForeverFont.subheader(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Group {
                if distanceKm <= 0 {
                    Text(togetherMessage)
                } else {
                    Text("\(Int(distanceKm.rounded())) km")
                }
            }
            .font(ForeverFont.bold(size: 15, relativeTo: .subheadline))
            .foregroundStyle(.white)
            .monospacedDigit()
        }
    }
}

// MARK: - Subviews

/// Horizontal dashed line shape; width is controlled via frame clipping.
struct DashedConnectorLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

private struct DashedConnectorLineView: View {
    let width: CGFloat

    private var dashStyle: StrokeStyle {
        StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 4])
    }

    var body: some View {
        DashedConnectorLine()
            .stroke(Color.white.opacity(0.5), style: dashStyle)
            .frame(width: max(0, width), height: 1.5)
    }
}

/// Single center heart matching the lock screen distance widget.
struct DistanceCenterHeart: View {
    var size: CGFloat = 10

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 14, height: 14)
    }
}

// MARK: - Animation View

/// Animated distance row: two avatars converge on a center heart as km counts down.
struct LiveDistanceClosingAnimationView: View {
    let myInitial: String
    let partnerInitial: String
    var viewModel: LiveDistanceClosingAnimationViewModel

    private let horizontalPadding: CGFloat = 8

    var body: some View {
        VStack(spacing: 14) {
            distanceLabel

            GeometryReader { geo in
                let halfGap = viewModel.connectorHalfGap(
                    totalWidth: geo.size.width,
                    horizontalPadding: horizontalPadding
                )
                let avatarSize = viewModel.configuration.avatarSize

                HStack(spacing: 0) {
                    ForeverMonogramBubble(
                        name: myInitial,
                        label: myInitial,
                        size: avatarSize,
                        style: .glassDark
                    )

                    DashedConnectorLineView(width: max(0, halfGap))

                    DistanceCenterHeart()

                    DashedConnectorLineView(width: max(0, halfGap))

                    ForeverMonogramBubble(
                        name: partnerInitial,
                        label: partnerInitial,
                        size: avatarSize,
                        style: .glassDark
                    )
                }
                .padding(.horizontal, horizontalPadding)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityDescription)
            }
            .frame(height: viewModel.configuration.avatarSize)
        }
    }

    private var distanceLabel: some View {
        DistanceCounter(
            progress: viewModel.animationProgress,
            startDistanceKm: Double(viewModel.configuration.startDistanceKm),
            togetherMessage: LiveDistanceClosingAnimationViewModel.togetherMessage
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var accessibilityLabelText: String {
        if viewModel.isTogether {
            return LiveDistanceClosingAnimationViewModel.togetherMessage
        }
        return "Our distance: \(Int(viewModel.animatedDistanceKm.rounded())) kilometers"
    }

    private var accessibilityDescription: String {
        if viewModel.isTogether {
            return "You and your partner are together."
        }
        return "You are \(Int(viewModel.animatedDistanceKm.rounded())) kilometers apart and moving closer."
    }
}

// MARK: - Widget Preview Card

/// Faux lock-screen widget card wrapping the closing-distance animation.
struct LiveDistanceWidgetPreviewCard: View {
    let myInitial: String
    let partnerInitial: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = LiveDistanceClosingAnimationViewModel()

    var body: some View {
        LiveDistanceClosingAnimationView(
            myInitial: myInitial,
            partnerInitial: partnerInitial,
            viewModel: viewModel
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(maxWidth: 340)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 28.0 / 255.0, green: 28.0 / 255.0, blue: 46.0 / 255.0),
                            Color(red: 18.0 / 255.0, green: 18.0 / 255.0, blue: 32.0 / 255.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 10)
        }
        .padding(.horizontal, OnboardingLayout.horizontalPadding)
        .onAppear {
            viewModel.startLoop(reduceMotion: reduceMotion)
        }
        .onDisappear {
            viewModel.stopLoop()
        }
        .onChange(of: reduceMotion) { _, isReduced in
            viewModel.stopLoop()
            viewModel.startLoop(reduceMotion: isReduced)
        }
    }
}

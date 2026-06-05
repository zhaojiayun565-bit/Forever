import SwiftUI

// MARK: - Configuration

struct LiveDistanceClosingAnimationConfiguration {
    var startDistanceKm: Int = 500
    var animationDuration: TimeInterval = 9
    var togetherPauseDuration: TimeInterval = 1.8
    var resetDuration: TimeInterval = 0.4
    var resetPauseDuration: TimeInterval = 0.6
    var avatarSize: CGFloat = 52
    var heartClusterWidth: CGFloat = 28
    var minConnectorGap: CGFloat = 2
}

// MARK: - View Model

@Observable
final class LiveDistanceClosingAnimationViewModel {
    var animationProgress: CGFloat = 0
    var showTogetherLabel = false

    let configuration: LiveDistanceClosingAnimationConfiguration

    private var loopTask: Task<Void, Never>?

    init(configuration: LiveDistanceClosingAnimationConfiguration = .init()) {
        self.configuration = configuration
    }

    var currentDistanceKm: Int {
        Int(round(Double(configuration.startDistanceKm) * Double(1 - animationProgress)))
    }

    static let togetherMessage = "We're together!"

    var distanceLabel: String {
        showTogetherLabel ? Self.togetherMessage : "\(currentDistanceKm) km"
    }

    /// Maps progress to the half-gap between each avatar and the heart cluster.
    func connectorHalfGap(totalWidth: CGFloat, horizontalPadding: CGFloat) -> CGFloat {
        let usableWidth = totalWidth - horizontalPadding * 2
        let occupiedByAvatars = configuration.avatarSize * 2 + configuration.heartClusterWidth
        let maxGap = max((usableWidth - occupiedByAvatars) / 2, configuration.minConnectorGap)
        let minGap = configuration.minConnectorGap
        return maxGap - (maxGap - minGap) * animationProgress
    }

    func startLoop(reduceMotion: Bool) {
        stopLoop()

        if reduceMotion {
            animationProgress = 1
            showTogetherLabel = true
            return
        }

        loopTask = Task { @MainActor in
            while !Task.isCancelled {
                animationProgress = 0
                showTogetherLabel = false

                withAnimation(.easeInOut(duration: configuration.animationDuration)) {
                    animationProgress = 1
                }

                try? await Task.sleep(for: .seconds(configuration.animationDuration))

                guard !Task.isCancelled else { return }

                withAnimation(.easeInOut(duration: 0.25)) {
                    showTogetherLabel = true
                }

                try? await Task.sleep(for: .seconds(configuration.togetherPauseDuration))

                guard !Task.isCancelled else { return }

                showTogetherLabel = false

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

// MARK: - Subviews

/// Monogram circle used in the distance closing row.
struct DistanceMonogramBubble: View {
    let label: String
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5)
                .background(Circle().fill(Color.white.opacity(0.12)))

            Text(label)
                .font(ForeverFont.bold(size: size * 0.3, relativeTo: .subheadline))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(width: size, height: size)
    }
}

/// Dashed connector segment whose width shrinks as partners move closer.
struct DistanceConnectorSegment: View {
    let width: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: max(0, width), height: 1.5)
            .overlay {
                if width > 0 {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0.75))
                        path.addLine(to: CGPoint(x: width, y: 0.75))
                    }
                    .stroke(
                        Color.white.opacity(0.5),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 4])
                    )
                }
            }
    }
}

/// Two overlapping hearts at the center of the distance row.
struct DistanceHeartCluster: View {
    var size: CGFloat = 11

    var body: some View {
        ZStack {
            Image(systemName: "heart.fill")
                .font(.system(size: size))
                .foregroundStyle(.white.opacity(0.9))
                .offset(x: -3)

            Image(systemName: "heart.fill")
                .font(.system(size: size))
                .foregroundStyle(.white.opacity(0.9))
                .offset(x: 3)
        }
        .frame(width: 28, height: 20)
    }
}

// MARK: - Animation View

/// Animated distance row: two avatars converge on a center heart as km counts down.
struct LiveDistanceClosingAnimationView: View {
    let myLabel: String
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
                    DistanceMonogramBubble(label: myLabel, size: avatarSize)

                    DistanceConnectorSegment(width: halfGap)

                    DistanceHeartCluster()

                    DistanceConnectorSegment(width: halfGap)

                    DistanceMonogramBubble(label: partnerInitial, size: avatarSize)
                }
                .padding(.horizontal, horizontalPadding)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityDescription)
            }
            .frame(height: viewModel.configuration.avatarSize)
        }
    }

    @ViewBuilder
    private var distanceLabel: some View {
        if viewModel.showTogetherLabel {
            Text(LiveDistanceClosingAnimationViewModel.togetherMessage)
                .font(ForeverFont.bold(size: 15, relativeTo: .subheadline))
                .foregroundStyle(.white)
                .accessibilityLabel(LiveDistanceClosingAnimationViewModel.togetherMessage)
        } else {
            HStack(spacing: 4) {
                Text("Our distance:")
                    .font(ForeverFont.subheader(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(.white.opacity(0.75))

                Text(viewModel.distanceLabel)
                    .font(ForeverFont.bold(size: 15, relativeTo: .subheadline))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: viewModel.distanceLabel)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Our distance: \(viewModel.distanceLabel)")
        }
    }

    private var accessibilityDescription: String {
        if viewModel.showTogetherLabel {
            return "You and your partner are together."
        }
        return "You are \(viewModel.currentDistanceKm) kilometers apart and moving closer."
    }
}

// MARK: - Widget Preview Card

/// Faux lock-screen widget card wrapping the closing-distance animation.
struct LiveDistanceWidgetPreviewCard: View {
    let myLabel: String
    let partnerInitial: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = LiveDistanceClosingAnimationViewModel()

    var body: some View {
        LiveDistanceClosingAnimationView(
            myLabel: myLabel,
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

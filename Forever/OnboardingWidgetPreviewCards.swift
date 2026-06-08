import SwiftUI

// MARK: - Shared preview frame

private struct OnboardingWidgetPreviewFrame<Content: View>: View {
    var isSquare: Bool = false
    @ViewBuilder var content: () -> Content

    private let squareSize: CGFloat = 170

    var body: some View {
        Group {
            if isSquare {
                content()
                    .frame(width: squareSize, height: squareSize)
            } else {
                content()
                    .frame(maxWidth: squareSize, minHeight: squareSize)
            }
        }
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
    }
}

// MARK: - Handwritten Notes

/// Widget mockup for the Handwritten Notes onboarding carousel slide.
struct HandwrittenNotesWidgetPreviewCard: View {
    var body: some View {
        Image("handwritten-notes-widget-preview")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 280)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 10)
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
    }
}

// MARK: - Love Messages

/// Lock-screen mockup for the Love Messages onboarding carousel slide.
struct LoveMessagesWidgetPreviewCard: View {
    var body: some View {
        Image("love-messages-widget-preview")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 280)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 10)
            .padding(.horizontal, OnboardingLayout.horizontalPadding)
    }
}

// MARK: - Days Together

/// Faux home-screen widget preview mirroring DaysTogetherWidgetView with onboarding names.
struct DaysTogetherWidgetPreviewCard: View {
    let myName: String
    let partnerName: String
    let anniversary: Date

    private var daysTogether: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: anniversary)
        let end = calendar.startOfDay(for: Date())
        return max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }

    var body: some View {
        OnboardingWidgetPreviewFrame(isSquare: true) {
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    ForeverMonogramBubble(
                        name: myName,
                        size: 54,
                        style: .glassDark
                    )

                    ForeverMonogramBubble(
                        name: partnerName,
                        size: 54,
                        style: .glassDark
                    )
                }
                .overlay {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: -2) {
                    Text("\(daysTogether)")
                        .font(ForeverFont.header(size: 30, relativeTo: .largeTitle))
                        .foregroundStyle(.white)

                    Text("Days Together")
                        .font(ForeverFont.subheader(size: 13, relativeTo: .caption))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 8)
        }
    }
}

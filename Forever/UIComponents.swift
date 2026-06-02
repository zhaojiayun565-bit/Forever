import Kingfisher
import SwiftUI
import UIKit

struct BubblyCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    
    var body: some View {
        content
            .padding(20)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 15, x: 0, y: 8)
    }
}

struct BubblyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

typealias ScaleButtonStyle = BubblyButtonStyle

/// Full-width pink Continue button used across onboarding.
struct OnboardingContinueButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isEnabled ? Color.pink : Color.gray)
                .cornerRadius(16)
        }
        .disabled(!isEnabled)
        .buttonStyle(ScaleButtonStyle())
    }
}

struct PairingCardView: View {
    var showsShadow: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "link")
                    .font(.title2)
                    .foregroundStyle(.pink)
                    .frame(width: 44, height: 44)
                    .background(.pink.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Connect Partner")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Enjoy the full app experience together")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: showsShadow ? .black.opacity(0.04) : .clear, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

/// Minus badge matching the iOS Home Screen edit-mode remove control.
struct EditModeRemoveBadge: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(uiColor: .systemBackground))
                    .overlay(
                        Circle()
                            .strokeBorder(Color.pink, lineWidth: 1)
                    )
                Capsule()
                    .fill(Color.pink)
                    .frame(width: 10, height: 2)
            }
            .frame(width: 22, height: 22)
            .shadow(color: .pink.opacity(0.25), radius: 1, x: 0, y: 0.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Remove photo")
    }
}

/// Downward-pointing triangle for tooltip tails.
private struct TooltipTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// Bouncing callout used above the map FAB during onboarding.
struct BouncingTooltip: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var text: String = "Tap here to drop your first memory!"
    var accentColor: Color = Color(red: 1.0, green: 45.0 / 255.0, blue: 85.0 / 255.0)

    @State private var bounce = false

    private var bubbleFill: Color {
        colorScheme == .dark
            ? Color(UIColor.secondarySystemGroupedBackground)
            : Color(red: 250.0 / 255.0, green: 250.0 / 255.0, blue: 250.0 / 255.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accentColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(bubbleFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)

            TooltipTriangle()
                .fill(bubbleFill)
                .frame(width: 18, height: 10)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        }
        .offset(y: reduceMotion ? 0 : (bounce ? -6 : 6))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                bounce = true
            }
        }
    }
}

/// Map annotation label: circular photo thumbnail and optional note capsule.
struct MemoryMapPinLabel: View {
    var image: UIImage?
    var imageURL: URL?
    let note: String?

    init(image: UIImage, note: String?) {
        self.image = image
        self.imageURL = nil
        self.note = note
    }

    init(imageURL: URL?, note: String?) {
        self.image = nil
        self.imageURL = imageURL
        self.note = note
    }

    private var displayNote: String? {
        guard let note else { return nil }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        HStack(spacing: 8) {
            thumbnail

            if let displayNote {
                Text(displayNote)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .frame(maxWidth: 140, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let imageURL {
                KFImage.url(imageURL)
                    .placeholder { Color.pink.opacity(0.3) }
                    .setProcessor(DownsamplingImageProcessor(size: CGSize(width: 100, height: 100)))
                    .scaleFactor(UIScreen.main.scale)
                    .cacheOriginalImage()
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.pink.opacity(0.3)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 3.5))
        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
    }
}

/// Circular add-memory button used on the map tab and onboarding map step.
struct MemoryMapFABButton: View {
    var accent: Color = .pink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(accent)
                .clipShape(Circle())
                .shadow(color: accent.opacity(0.4), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(BubblyButtonStyle())
        .accessibilityLabel("Add memory")
    }
}

/// Page dots with explicit spacing for use below a paged image carousel.
struct MemoryPageIndicator: View {
    let count: Int
    let selection: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< count, id: \.self) { index in
                Circle()
                    .fill(index == selection ? Color.white : Color.white.opacity(0.35))
                    .frame(width: 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: selection)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Photo \(selection + 1) of \(count)")
    }
}

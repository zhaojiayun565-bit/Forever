import SwiftUI

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

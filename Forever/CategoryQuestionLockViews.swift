import SwiftUI

/// Centered message shown when the daily category question limit is reached.
struct CategoryDailyLockOverlay: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "hourglass")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(QuestionsTheme.accent)
                .symbolRenderingMode(.hierarchical)

            Text("Great conversation today!")
                .font(ForeverFont.header(.headline))
                .multilineTextAlignment(.center)

            Text("Your next prompt unlocks tomorrow.")
                .font(ForeverFont.subheader(.subheadline))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
        .padding(.horizontal, 32)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Frosted blur over a locked question or category card.
    func questionCardLockOverlay(isLocked: Bool) -> some View {
        overlay {
            if isLocked {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .allowsHitTesting(false)
            }
        }
        .allowsHitTesting(!isLocked)
    }

    /// Full-area overlay when the global daily category limit is active.
    func globalCategoryLockOverlay(isActive: Bool) -> some View {
        overlay {
            if isActive {
                ZStack {
                    Color.clear
                    CategoryDailyLockOverlay()
                }
            }
        }
    }
}

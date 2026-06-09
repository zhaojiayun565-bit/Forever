import SwiftUI

extension View {
    /// Frosted blur with centered lock copy over a locked question or category card.
    func questionCardLockOverlay(isLocked: Bool) -> some View {
        overlay {
            if isLocked {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                    Text(QuestionsTheme.dailyUnlockMessage)
                        .font(ForeverFont.subheader(.subheadline))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .allowsHitTesting(false)
            }
        }
        .allowsHitTesting(!isLocked)
    }
}

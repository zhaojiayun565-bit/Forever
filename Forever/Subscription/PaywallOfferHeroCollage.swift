import SwiftUI

/// Staggered paywall step 1 hero: widget gallery, memory map, lock screen message.
struct PaywallOfferHeroCollage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var revealedCards: [Bool] = [false, false, false]

    private static let revealDelay: TimeInterval = 0.35
    private static let cardWidth: CGFloat = 200
    private static let collageWidth: CGFloat = 300
    private static let collageHeight: CGFloat = 400

    var body: some View {
        ZStack {
            collageLayer(
                index: 0,
                offset: CGSize(width: -40, height: -72)
            ) {
                Image("paywall-widget-gallery-preview")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.cardWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
            }

            collageLayer(
                index: 1,
                offset: CGSize(width: 48, height: 48)
            ) {
                Image("paywall-memory-map-preview")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.cardWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
            }

            collageLayer(
                index: 2,
                offset: CGSize(width: -36, height: 208)
            ) {
                Image("paywall-lock-screen-preview")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Self.cardWidth * 0.92)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
            }
        }
        .frame(width: Self.collageWidth, height: Self.collageHeight)
        .onAppear(perform: startReveal)
    }

    @ViewBuilder
    private func collageLayer<C: View>(
        index: Int,
        offset: CGSize,
        @ViewBuilder content: () -> C
    ) -> some View {
        content()
            .offset(offset)
            .opacity(revealedCards[index] ? 1 : 0)
            .scaleEffect(revealedCards[index] ? 1 : 0.92)
            .zIndex(Double(index))
    }

    private func startReveal() {
        if reduceMotion {
            revealedCards = [true, true, true]
            return
        }

        for index in revealedCards.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealDelay * Double(index)) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    revealedCards[index] = true
                }
            }
        }
    }
}

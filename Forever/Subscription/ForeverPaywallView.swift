import RevenueCat
import RevenueCatUI
import SwiftUI

/// RevenueCat-hosted paywall with purchase / restore callbacks.
struct ForeverPaywallView: View {
    @Environment(SubscriptionManager.self) private var subscription
    var offering: Offering?
    var onCompleted: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        Group {
            if let offering = offering ?? subscription.currentOffering {
                paywallBody(offering: offering)
            } else {
                ProgressView("Loading plans…")
                    .task { await subscription.refresh() }
            }
        }
    }

    @ViewBuilder
    private func paywallBody(offering: Offering) -> some View {
        let paywall = PaywallView(offering: offering)
            .onPurchaseCompleted { _ in onCompleted?() }
            .onRestoreCompleted { info in
                if info.entitlements[RevenueCatConfiguration.proEntitlementID]?.isActive == true {
                    onCompleted?()
                }
            }

        if let onDismiss {
            paywall.onRequestedDismissal { onDismiss() }
        } else {
            paywall
        }
    }
}

/// Presents the paywall only when the user does not have Pro.
struct ForeverPaywallGateModifier: ViewModifier {
    @Environment(SubscriptionManager.self) private var subscription
    @Binding var isPresented: Bool
    var onPurchaseCompleted: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                ForeverPaywallView(onCompleted: {
                    onPurchaseCompleted?()
                    isPresented = false
                }, onDismiss: {
                    isPresented = false
                })
            }
    }
}

extension View {
    /// Shows a RevenueCat paywall sheet when `isPresented` is true.
    func foreverPaywall(
        isPresented: Binding<Bool>,
        onPurchaseCompleted: (() -> Void)? = nil
    ) -> some View {
        modifier(ForeverPaywallGateModifier(isPresented: isPresented, onPurchaseCompleted: onPurchaseCompleted))
    }

    /// Presents RevenueCat paywall automatically when Pro is not active.
    func presentForeverPaywallIfNeeded(
        onPurchaseCompleted: (() -> Void)? = nil
    ) -> some View {
        presentPaywallIfNeeded(
            requiredEntitlementIdentifier: RevenueCatConfiguration.proEntitlementID,
            purchaseCompleted: { _ in onPurchaseCompleted?() },
            restoreCompleted: { _ in onPurchaseCompleted?() }
        )
    }
}

/// Gates content behind the Pro entitlement; tapping while locked opens the paywall.
struct ProGated<Locked: View, Unlocked: View>: View {
    @Environment(SubscriptionManager.self) private var subscription
    @Binding var showPaywall: Bool
    @ViewBuilder var locked: () -> Locked
    @ViewBuilder var unlocked: () -> Unlocked

    var body: some View {
        if subscription.isPro {
            unlocked()
        } else {
            Button {
                showPaywall = true
            } label: {
                locked()
            }
            .buttonStyle(.plain)
        }
    }
}

import RevenueCat
import SafariServices
import SwiftUI

// MARK: - Flow step

enum PaywallFlowStep {
    case offer
    case reminder
    case purchase
}

enum PaywallPlanOption: String, CaseIterable {
    case monthly
    case yearly
}

// MARK: - Theme

enum PaywallTheme {
    static let accent = Color(red: 1.0, green: 45.0 / 255.0, blue: 85.0 / 255.0)
    static let trustGreen = Color(red: 52.0 / 255.0, green: 199.0 / 255.0, blue: 89.0 / 255.0)
    static let timelineOrange = Color(red: 1.0, green: 149.0 / 255.0, blue: 0)

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.08, green: 0.08, blue: 0.1) : .white
    }

    static func primaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : .black
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.65) : Color.black.opacity(0.55)
    }

    static func mediaPlaceholder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.75)
    }

    static func footerLink(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.45) : Color.black.opacity(0.35)
    }

    static func planCardBackground(for scheme: ColorScheme, isSelected: Bool) -> Color {
        if isSelected {
            return scheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.06)
        }
        return scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)
    }

    static func planCardBorder(for scheme: ColorScheme, isSelected: Bool) -> Color {
        isSelected ? accent : (scheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.12))
    }

    static func timelineConnector(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.12)
    }
}

// MARK: - Container

/// Custom 3-step paywall matching Figma; purchases via RevenueCat on step 3.
struct ForeverCustomPaywallFlow: View {
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    var onCompleted: () -> Void
    var onSkip: (() -> Void)?

    @State private var step: PaywallFlowStep = .offer
    @State private var selectedPlan: PaywallPlanOption = .yearly
    @State private var restoreNotice: String?
    @State private var legalURL: URL?
    @State private var showLegalSafari = false

    private var selectedPackage: Package? {
        switch selectedPlan {
        case .monthly:
            subscription.monthlyPackage
        case .yearly:
            subscription.yearlyPackage
        }
    }

    var body: some View {
        ZStack {
            PaywallTheme.background(for: colorScheme)
                .ignoresSafeArea()

            if subscription.currentOffering == nil && subscription.isLoading && selectedPackage == nil {
                ProgressView("Loading plans…")
                    .tint(PaywallTheme.accent)
            } else {
                VStack(spacing: 0) {
                    stepContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    PaywallFooterLinks(
                        colorScheme: colorScheme,
                        onRestore: restorePurchases,
                        onTerms: { openLegal(RevenueCatConfiguration.termsURL) },
                        onPrivacy: { openLegal(RevenueCatConfiguration.privacyURL) }
                    )

                    if let onSkip {
                        Button("Continue without Pro") {
                            onSkip()
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(PaywallTheme.footerLink(for: colorScheme))
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    } else {
                        Spacer().frame(height: 24)
                    }
                }
            }

            if subscription.isLoading {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(PaywallTheme.accent)
            }
        }
        .task {
            await subscription.refresh()
            if subscription.yearlyPackage != nil {
                selectedPlan = .yearly
            } else if subscription.monthlyPackage != nil {
                selectedPlan = .monthly
            }
            if subscription.isPro {
                onCompleted()
            }
        }
        .overlay(alignment: .top) {
            if let message = subscription.lastErrorMessage {
                PaywallErrorBanner(message: message) {
                    subscription.clearLastError()
                }
                .padding(.top, 8)
                .padding(.horizontal, 20)
            } else if let notice = restoreNotice {
                PaywallErrorBanner(message: notice, isInformational: true) {
                    restoreNotice = nil
                }
                .padding(.top, 8)
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showLegalSafari) {
            if let legalURL {
                SafariView(url: legalURL)
                    .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .offer:
            PaywallOfferStepView(
                package: subscription.yearlyPackage ?? subscription.monthlyPackage,
                colorScheme: colorScheme,
                onContinue: { withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step = .reminder } }
            )
        case .reminder:
            PaywallReminderStepView(
                colorScheme: colorScheme,
                onContinue: advanceFromReminder
            )
        case .purchase:
            PaywallPurchaseStepView(
                monthlyPackage: subscription.monthlyPackage,
                yearlyPackage: subscription.yearlyPackage,
                selectedPlan: $selectedPlan,
                colorScheme: colorScheme,
                onPurchase: purchaseSelectedPackage
            )
        }
    }

    private func advanceFromReminder() {
        Task {
            await NotificationAuthorizationManager.requestAtPaywallIfNeeded()
            await MainActor.run {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    step = .purchase
                }
            }
        }
    }

    private func purchaseSelectedPackage() {
        guard let package = selectedPackage ?? subscription.preferredTrialPackage else {
            subscription.lastErrorMessage = SubscriptionError.packageNotFound.localizedDescription
            return
        }

        Task {
            do {
                _ = try await subscription.purchase(package)
                if subscription.isPro {
                    onCompleted()
                }
            } catch SubscriptionError.purchaseCancelled {
                subscription.clearLastError()
            } catch {
                // lastErrorMessage set by manager
            }
        }
    }

    private func restorePurchases() {
        Task {
            do {
                _ = try await subscription.restorePurchases()
                if subscription.isPro {
                    onCompleted()
                } else {
                    restoreNotice = "No active subscription found."
                }
            } catch {
                restoreNotice = error.localizedDescription
            }
        }
    }

    private func openLegal(_ url: URL?) {
        guard let url else { return }
        legalURL = url
        showLegalSafari = true
    }
}

// MARK: - Step 1: Offer

private struct PaywallOfferStepView: View {
    let package: Package?
    let colorScheme: ColorScheme
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            Text("We want you to try Forever for free")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(PaywallTheme.primaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer(minLength: 20)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(PaywallTheme.mediaPlaceholder(for: colorScheme))
                .frame(maxWidth: 280)
                .frame(maxHeight: 360)
                .padding(.horizontal, 48)

            Spacer(minLength: 20)

            PaywallTrustRow(colorScheme: colorScheme)

            Spacer(minLength: 24)

            VStack(spacing: 10) {
                PaywallPrimaryButton(title: "Try for $0.00", action: onContinue)

                if let package {
                    Text(PaywallPricingFormatter.priceSubtitle(for: package))
                        .font(.subheadline)
                        .foregroundStyle(PaywallTheme.primaryText(for: colorScheme))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Step 2: Reminder / notifications

private struct PaywallReminderStepView: View {
    let colorScheme: ColorScheme
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            Text("We'll remind you before your free trial ends")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(PaywallTheme.primaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("Turn on notifications for Forever to get the reminder")
                .font(.title3)
                .foregroundStyle(PaywallTheme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 12)

            Spacer(minLength: 20)

            Image(systemName: "bell.fill")
                .font(.system(size: 160))
                .foregroundStyle(PaywallTheme.accent)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 360)

            Spacer(minLength: 20)

            PaywallTrustRow(colorScheme: colorScheme)

            Spacer(minLength: 24)

            PaywallPrimaryButton(title: "Continue for FREE", action: onContinue)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
        }
    }
}

// MARK: - Step 3: Purchase

private struct PaywallPurchaseStepView: View {
    let monthlyPackage: Package?
    let yearlyPackage: Package?
    @Binding var selectedPlan: PaywallPlanOption
    let colorScheme: ColorScheme
    let onPurchase: () -> Void

    private var activePackage: Package? {
        switch selectedPlan {
        case .monthly: monthlyPackage
        case .yearly: yearlyPackage
        }
    }

    private var trialDays: Int {
        guard let yearlyPackage,
              let intro = yearlyPackage.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return 7 }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day: return max(1, period.value)
        case .week: return max(1, period.value * 7)
        default: return 7
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                PaywallStepProgressHeader(colorScheme: colorScheme)
                    .padding(.top, 8)

                PaywallTrialHeadline(trialDays: trialDays, colorScheme: colorScheme)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                PaywallTrialTimeline(
                    trialDays: trialDays,
                    colorScheme: colorScheme
                )
                .padding(.horizontal, 24)
                .padding(.top, 24)

                PaywallPlanPicker(
                    monthlyPackage: monthlyPackage,
                    yearlyPackage: yearlyPackage,
                    selectedPlan: $selectedPlan,
                    colorScheme: colorScheme
                )
                .padding(.horizontal, 24)
                .padding(.top, 24)

                PaywallTrustRow(colorScheme: colorScheme)
                    .padding(.top, 24)

                VStack(spacing: 10) {
                    PaywallPrimaryButton(
                        title: PaywallPricingFormatter.purchaseCTATitle(trialDays: trialDays),
                        action: onPurchase
                    )
                    .disabled(activePackage == nil)

                    if let yearlyPackage, selectedPlan == .yearly {
                        Text(PaywallPricingFormatter.trialPurchaseFootnote(
                            yearlyPackage: yearlyPackage,
                            trialDays: trialDays
                        ))
                        .font(.subheadline)
                        .foregroundStyle(PaywallTheme.secondaryText(for: colorScheme))
                        .multilineTextAlignment(.center)
                    } else if let package = activePackage {
                        Text(PaywallPricingFormatter.priceSubtitle(for: package))
                            .font(.subheadline)
                            .foregroundStyle(PaywallTheme.secondaryText(for: colorScheme))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Step 3 subviews

private struct PaywallStepProgressHeader: View {
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 12) {
            Text("One subscription for two accounts")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(PaywallTheme.secondaryText(for: colorScheme))

            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(PaywallTheme.accent)
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

private struct PaywallTrialHeadline: View {
    let trialDays: Int
    let colorScheme: ColorScheme

    var body: some View {
        (
            Text("Start your \(trialDays)-day ")
            + Text("FREE").foregroundStyle(PaywallTheme.accent).bold()
            + Text(" trial to continue")
        )
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .foregroundStyle(PaywallTheme.primaryText(for: colorScheme))
        .multilineTextAlignment(.center)
    }
}

private struct PaywallTrialTimeline: View {
    let trialDays: Int
    let colorScheme: ColorScheme

    private var reminderDay: Int { max(1, trialDays - 2) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineRow(
                icon: "lock.fill",
                iconBackground: PaywallTheme.timelineOrange,
                title: "Today",
                body: "Unlock all of Forever's features for you and your partner.",
                showsConnector: true
            )

            timelineRow(
                icon: "bell.fill",
                iconBackground: PaywallTheme.accent,
                title: "In \(reminderDay) Days - Reminder",
                body: "We'll send you a reminder that your trial is ending soon.",
                showsConnector: true
            )

            timelineRow(
                icon: "diamond.fill",
                iconBackground: PaywallTheme.primaryText(for: colorScheme),
                title: "In \(trialDays) Days - Billing Starts",
                body: "You'll be charged on \(PaywallPricingFormatter.billingStartDate(trialDays: trialDays)) unless you cancel anytime before.",
                showsConnector: false
            )
        }
    }

    private func timelineRow(
        icon: String,
        iconBackground: Color,
        title: String,
        body: String,
        showsConnector: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(iconBackground)
                    .clipShape(Circle())

                if showsConnector {
                    Rectangle()
                        .fill(PaywallTheme.timelineConnector(for: colorScheme))
                        .frame(width: 2)
                        .frame(minHeight: 48)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PaywallTheme.primaryText(for: colorScheme))

                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(PaywallTheme.secondaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, showsConnector ? 16 : 0)
        }
    }
}

private struct PaywallPlanPicker: View {
    let monthlyPackage: Package?
    let yearlyPackage: Package?
    @Binding var selectedPlan: PaywallPlanOption
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 12) {
            if let monthlyPackage {
                PaywallPlanCard(
                    title: "Monthly",
                    priceLabel: PaywallPricingFormatter.planCardPriceLabel(for: monthlyPackage),
                    badge: nil,
                    isSelected: selectedPlan == .monthly,
                    colorScheme: colorScheme
                ) {
                    selectedPlan = .monthly
                }
            }

            if let yearlyPackage {
                PaywallPlanCard(
                    title: "Yearly",
                    priceLabel: PaywallPricingFormatter.planCardPriceLabel(for: yearlyPackage),
                    badge: PaywallPricingFormatter.freeTrialBadgeText(for: yearlyPackage),
                    isSelected: selectedPlan == .yearly,
                    colorScheme: colorScheme
                ) {
                    selectedPlan = .yearly
                }
            }
        }
    }
}

private struct PaywallPlanCard: View {
    let title: String
    let priceLabel: String
    let badge: String?
    let isSelected: Bool
    let colorScheme: ColorScheme
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(PaywallTheme.accent)
                        .clipShape(Capsule())
                }

                Text(title)
                    .font(.headline)
                    .foregroundStyle(PaywallTheme.primaryText(for: colorScheme))

                Text(priceLabel)
                    .font(.subheadline)
                    .foregroundStyle(PaywallTheme.secondaryText(for: colorScheme))

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .frame(minHeight: 100)
            .background(PaywallTheme.planCardBackground(for: colorScheme, isSelected: isSelected))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        PaywallTheme.planCardBorder(for: colorScheme, isSelected: isSelected),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared components

private struct PaywallTrustRow: View {
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.body.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(PaywallTheme.trustGreen)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text("No Payment Due Now")
                .font(.body.weight(.semibold))
                .foregroundStyle(PaywallTheme.primaryText(for: colorScheme))
        }
    }
}

struct PaywallPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isEnabled ? PaywallTheme.accent : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct PaywallFooterLinks: View {
    let colorScheme: ColorScheme
    let onRestore: () -> Void
    let onTerms: () -> Void
    let onPrivacy: () -> Void

    var body: some View {
        HStack {
            Button("Restore Purchases", action: onRestore)
            Spacer()
            Button("Terms", action: onTerms)
                .disabled(RevenueCatConfiguration.termsURL == nil)
            Spacer()
            Button("Policy", action: onPrivacy)
                .disabled(RevenueCatConfiguration.privacyURL == nil)
        }
        .font(.footnote)
        .foregroundStyle(PaywallTheme.footerLink(for: colorScheme))
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
    }
}

private struct PaywallErrorBanner: View {
    let message: String
    var isInformational: Bool = false
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(isInformational ? Color.blue.opacity(0.12) : Color.red.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

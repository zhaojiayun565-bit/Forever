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
    static let trustGreen = Color(red: 51.0 / 255.0, green: 199.0 / 255.0, blue: 89.0 / 255.0)

    private static let darkSecondary = Color(red: 166.0 / 255.0, green: 166.0 / 255.0, blue: 166.0 / 255.0)
    private static let darkFooterLink = Color(red: 140.0 / 255.0, green: 140.0 / 255.0, blue: 140.0 / 255.0)
    private static let darkPlanCardBorder = Color(red: 56.0 / 255.0, green: 56.0 / 255.0, blue: 56.0 / 255.0)

    /// Timeline steps 1–2 circle fill (#FF9AAD).
    static let timelineStepMuted = Color(red: 255.0 / 255.0, green: 154.0 / 255.0, blue: 173.0 / 255.0)

    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .black : .white
    }

    static func primaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : .black
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkSecondary : Color.black.opacity(0.55)
    }

    static func mediaPlaceholder(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.75)
    }

    static func footerLink(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkFooterLink : Color.black.opacity(0.35)
    }

    /// Pricing line under the CTA (white in dark Figma frame).
    static func ctaSubtext(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : .black
    }

    static func planCardBorder(for scheme: ColorScheme, isSelected: Bool) -> Color {
        if isSelected { return accent }
        return scheme == .dark ? darkPlanCardBorder : Color.black.opacity(0.12)
    }

    static func planCardBorderWidth(isSelected: Bool) -> CGFloat {
        isSelected ? 2.5 : 1
    }

    /// Vertical connector between timeline steps (#FF2D55 at 10% light / 30% dark).
    static func timelineConnector(for scheme: ColorScheme) -> Color {
        accent.opacity(scheme == .dark ? 0.30 : 0.10)
    }

    static func freeTrialBadgeBackground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : accent
    }

    static func freeTrialBadgeForeground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .black : .white
    }
}

// MARK: - Step 3 metrics (Figma 319:504 / 284:119)

private enum PaywallStep3Metrics {
    static let horizontalPadding: CGFloat = 40
    static let subheadToHeadline: CGFloat = 12
    static let headlineToTimeline: CGFloat = 48
    static let timelineToPlans: CGFloat = 32
    static let plansToTrust: CGFloat = 10
    static let footerSpacing: CGFloat = 16

    static let subheadSize: CGFloat = 17
    static let headlineSize: CGFloat = 30
    static let timelineTitleSize: CGFloat = 17
    static let timelineBodySize: CGFloat = 15
    static let planTitleSize: CGFloat = 16
    static let planPriceSize: CGFloat = 15
    static let badgeSize: CGFloat = 11
    static let ctaSize: CGFloat = 17
    static let ctaSubtextSize: CGFloat = 14
    static let trustLabelSize: CGFloat = 17

    static let timelineCircleSize: CGFloat = 40
    static let timelineConnectorWidth: CGFloat = 9
    static let timelineConnectorHeight: CGFloat = 66
    static let timelineConnectorRadius: CGFloat = 2
    static let timelineRowMinHeight: CGFloat = 100
    static let timelineIconToTextSpacing: CGFloat = 14

    static let planCardCornerRadius: CGFloat = 16
    static let planCardMinHeight: CGFloat = 96
    static let planCardPaddingTop: CGFloat = 16
    static let planCardPaddingHorizontal: CGFloat = 14
    static let planCardPaddingBottom: CGFloat = 14
    static let planCardInnerSpacing: CGFloat = 10
    static let planCardSpacing: CGFloat = 12

    static let badgeHorizontalPadding: CGFloat = 10
    static let badgeVerticalPadding: CGFloat = 5
    static let badgeCornerRadius: CGFloat = 10
    static let badgeTopOffset: CGFloat = -11

    static let timelineTodayBody = "Unlock all of Forever's features for you and your partner."
}

private enum PaywallStepMetrics {
    static let headerTopPadding: CGFloat = 16
    static let headerToCollageSpacing: CGFloat = 28
    static let collageToDockSpacing: CGFloat = 32
    static let bottomDockSpacing: CGFloat = 12
    static let bottomDockHorizontalPadding: CGFloat = 32
    static let yearlyPlanBadgeText = "40% OFF"
}

// MARK: - Container

/// Custom 3-step paywall matching Figma; purchases via RevenueCat on step 3.
struct ForeverCustomPaywallFlow: View {
    @Environment(SubscriptionManager.self) private var subscription
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    var onCompleted: () -> Void

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

    private var purchaseTrialDays: Int {
        guard let yearlyPackage = subscription.yearlyPackage,
              let intro = yearlyPackage.storeProduct.introductoryDiscount,
              intro.paymentMode == .freeTrial else { return 7 }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day: return max(1, period.value)
        case .week: return max(1, period.value * 7)
        default: return 7
        }
    }

    private var bottomDockPackage: Package? {
        switch step {
        case .offer, .reminder:
            subscription.yearlyPackage ?? subscription.monthlyPackage
        case .purchase:
            subscription.yearlyPackage ?? selectedPackage
        }
    }

    private var bottomDockTitle: String {
        switch step {
        case .offer:
            "Try for $0.00"
        case .reminder:
            "Continue for FREE"
        case .purchase:
            PaywallPricingFormatter.purchaseCTATitle(trialDays: purchaseTrialDays)
        }
    }

    private var bottomDockIsEnabled: Bool {
        step != .purchase || selectedPackage != nil
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

                    PaywallBottomDock(
                        colorScheme: colorScheme,
                        ctaTitle: bottomDockTitle,
                        package: bottomDockPackage,
                        isEnabled: bottomDockIsEnabled,
                        onCTA: bottomDockAction,
                        onRestore: restorePurchases,
                        onTerms: { openLegal(RevenueCatConfiguration.termsURL) },
                        onPrivacy: { openLegal(RevenueCatConfiguration.privacyURL) }
                    )
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
        .onChange(of: subscription.isPro) { _, isPro in
            if isPro { onCompleted() }
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
            PaywallOfferStepView(colorScheme: colorScheme)
        case .reminder:
            PaywallReminderStepView(colorScheme: colorScheme)
        case .purchase:
            PaywallPurchaseStepView(
                monthlyPackage: subscription.monthlyPackage,
                yearlyPackage: subscription.yearlyPackage,
                selectedPlan: $selectedPlan,
                trialDays: purchaseTrialDays,
                colorScheme: colorScheme
            )
        }
    }

    private func bottomDockAction() {
        switch step {
        case .offer:
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                step = .reminder
            }
        case .reminder:
            advanceFromReminder()
        case .purchase:
            purchaseSelectedPackage()
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
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 0) {
            Text("We want you to try Forever for free")
                .font(ForeverFont.header(size: 32, relativeTo: .title))
                .foregroundStyle(PaywallTheme.primaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, PaywallStepMetrics.headerTopPadding)

            PaywallOfferHeroCollage()
                .padding(.top, PaywallStepMetrics.headerToCollageSpacing)
                .padding(.horizontal, 48)
                .padding(.bottom, PaywallStepMetrics.collageToDockSpacing)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Step 2: Reminder / notifications

private struct PaywallReminderStepView: View {
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 0) {
            Text("We'll remind you before your free trial ends")
                .font(ForeverFont.header(size: 32, relativeTo: .title))
                .foregroundStyle(PaywallTheme.primaryText(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, PaywallStepMetrics.headerTopPadding)

            Text("Turn on notifications for Forever to get the reminder")
                .font(ForeverFont.subheader(.title3))
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

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Step 3: Purchase

private struct PaywallPurchaseStepView: View {
    let monthlyPackage: Package?
    let yearlyPackage: Package?
    @Binding var selectedPlan: PaywallPlanOption
    let trialDays: Int
    let colorScheme: ColorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                PaywallPartnerSubheadHeader(colorScheme: colorScheme)
                    .padding(.top, 24)

                PaywallTrialHeadline(trialDays: trialDays, colorScheme: colorScheme)
                    .frame(maxWidth: .infinity)
                    .padding(.top, PaywallStep3Metrics.subheadToHeadline)

                PaywallTrialTimeline(trialDays: trialDays, colorScheme: colorScheme)
                    .padding(.top, PaywallStep3Metrics.headlineToTimeline)

                PaywallPlanPicker(
                    monthlyPackage: monthlyPackage,
                    yearlyPackage: yearlyPackage,
                    selectedPlan: $selectedPlan,
                    colorScheme: colorScheme
                )
                .padding(.top, PaywallStep3Metrics.timelineToPlans)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, PaywallStep3Metrics.horizontalPadding)
        }
    }
}

// MARK: - Step 3 subviews

private struct PaywallPartnerSubheadHeader: View {
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 4) {
            Text("Your partner doesn't pay anything")
                .font(ForeverFont.subheader(size: PaywallStep3Metrics.subheadSize, relativeTo: .subheadline))
                .foregroundStyle(PaywallTheme.primaryText(for: colorScheme))
                .multilineTextAlignment(.center)

            Capsule()
                .fill(PaywallTheme.accent)
                .frame(height: 3)
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity)
    }
}

private struct PaywallTrialHeadline: View {
    let trialDays: Int
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 0) {
            Text("Start your \(trialDays)-day")
                .font(ForeverFont.header(size: PaywallStep3Metrics.headlineSize, relativeTo: .title))
                .foregroundStyle(PaywallTheme.primaryText(for: colorScheme))

            secondLine
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var secondLine: some View {
        let font = ForeverFont.header(size: PaywallStep3Metrics.headlineSize, relativeTo: .title)
        if colorScheme == .dark {
            Text("FREE trial to continue")
                .font(font)
                .foregroundStyle(PaywallTheme.primaryText(for: colorScheme))
        } else {
            (
                Text("FREE")
                    .foregroundStyle(PaywallTheme.accent)
                    .bold()
                + Text(" trial to continue")
                    .foregroundStyle(PaywallTheme.primaryText(for: colorScheme))
            )
            .font(font)
        }
    }
}

private struct PaywallTrialTimeline: View {
    let trialDays: Int
    let colorScheme: ColorScheme

    private var reminderDay: Int { max(1, trialDays - 2) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineRow(
                emoji: "🔒",
                isBilling: false,
                title: "Today",
                body: PaywallStep3Metrics.timelineTodayBody,
                showsConnector: true
            )

            timelineRow(
                emoji: "🔔",
                isBilling: false,
                title: "In \(reminderDay) Days - Reminder",
                body: "We'll send you a reminder that your trial is ending soon.",
                showsConnector: true
            )

            timelineRow(
                emoji: "💎",
                isBilling: true,
                title: "In \(trialDays) Days - Billing Starts",
                body: "You'll be charged on \(PaywallPricingFormatter.billingStartDate(trialDays: trialDays)) unless you cancel anytime before.",
                showsConnector: false
            )
        }
    }

    private func timelineRow(
        emoji: String,
        isBilling: Bool,
        title: String,
        body: String,
        showsConnector: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: PaywallStep3Metrics.timelineIconToTextSpacing) {
            VStack(spacing: 0) {
                Text(emoji)
                    .font(ForeverFont.body(size: 16, relativeTo: .callout))
                    .frame(width: PaywallStep3Metrics.timelineCircleSize, height: PaywallStep3Metrics.timelineCircleSize)
                    .background(isBilling ? PaywallTheme.accent : PaywallTheme.timelineStepMuted)
                    .clipShape(Circle())

                if showsConnector {
                    RoundedRectangle(cornerRadius: PaywallStep3Metrics.timelineConnectorRadius, style: .continuous)
                        .fill(PaywallTheme.timelineConnector(for: colorScheme))
                        .frame(
                            width: PaywallStep3Metrics.timelineConnectorWidth,
                            height: PaywallStep3Metrics.timelineConnectorHeight
                        )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ForeverFont.bold(size: PaywallStep3Metrics.timelineTitleSize, relativeTo: .headline))
                    .foregroundStyle(PaywallTheme.primaryText(for: colorScheme))

                Text(body)
                    .font(ForeverFont.body(size: PaywallStep3Metrics.timelineBodySize, relativeTo: .footnote))
                    .foregroundStyle(PaywallTheme.secondaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minHeight: showsConnector ? PaywallStep3Metrics.timelineRowMinHeight : nil, alignment: .top)
    }
}

private struct PaywallPlanPicker: View {
    let monthlyPackage: Package?
    let yearlyPackage: Package?
    @Binding var selectedPlan: PaywallPlanOption
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: PaywallStep3Metrics.planCardSpacing) {
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
                    badge: PaywallStepMetrics.yearlyPlanBadgeText,
                    isSelected: selectedPlan == .yearly,
                    colorScheme: colorScheme
                ) {
                    selectedPlan = .yearly
                }
            }
        }
    }
}

private struct PaywallPlanBadge: View {
    let text: String
    let colorScheme: ColorScheme

    var body: some View {
        Text(text)
            .font(ForeverFont.emphasis(size: PaywallStep3Metrics.badgeSize, relativeTo: .caption2))
            .foregroundStyle(PaywallTheme.freeTrialBadgeForeground(for: colorScheme))
            .padding(.horizontal, PaywallStep3Metrics.badgeHorizontalPadding)
            .padding(.vertical, PaywallStep3Metrics.badgeVerticalPadding)
            .background(PaywallTheme.freeTrialBadgeBackground(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: PaywallStep3Metrics.badgeCornerRadius, style: .continuous))
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
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: PaywallStep3Metrics.planCardInnerSpacing) {
                    Text(title)
                        .font(ForeverFont.bold(size: PaywallStep3Metrics.planTitleSize, relativeTo: .headline))
                        .foregroundStyle(PaywallTheme.primaryText(for: colorScheme))
                        .padding(.top, badge == nil ? 0 : 8)

                    Text(priceLabel)
                        .font(ForeverFont.body(size: PaywallStep3Metrics.planPriceSize, relativeTo: .subheadline))
                        .foregroundStyle(PaywallTheme.secondaryText(for: colorScheme))

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, PaywallStep3Metrics.planCardPaddingTop)
                .padding(.horizontal, PaywallStep3Metrics.planCardPaddingHorizontal)
                .padding(.bottom, PaywallStep3Metrics.planCardPaddingBottom)
                .frame(minHeight: PaywallStep3Metrics.planCardMinHeight)

                PaywallPlanSelectionIndicator(isSelected: isSelected, colorScheme: colorScheme)
                    .padding(12)
            }
            .overlay(
                RoundedRectangle(cornerRadius: PaywallStep3Metrics.planCardCornerRadius, style: .continuous)
                    .strokeBorder(
                        PaywallTheme.planCardBorder(for: colorScheme, isSelected: isSelected),
                        lineWidth: PaywallTheme.planCardBorderWidth(isSelected: isSelected)
                    )
            )
            .overlay(alignment: .top) {
                if let badge {
                    PaywallPlanBadge(text: badge, colorScheme: colorScheme)
                        .offset(y: PaywallStep3Metrics.badgeTopOffset)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PaywallPlanSelectionIndicator: View {
    let isSelected: Bool
    let colorScheme: ColorScheme

    var body: some View {
        Group {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(ForeverFont.bold(.caption))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(PaywallTheme.accent)
                    .clipShape(Circle())
            } else {
                Circle()
                    .strokeBorder(
                        PaywallTheme.planCardBorder(for: colorScheme, isSelected: false),
                        lineWidth: 2
                    )
                    .frame(width: 22, height: 22)
            }
        }
    }
}

// MARK: - Shared components

/// Trust row, CTA, price subtext, and footer links pinned near the bottom of the screen.
private struct PaywallBottomDock: View {
    let colorScheme: ColorScheme
    let ctaTitle: String
    let package: Package?
    var isEnabled: Bool = true
    let onCTA: () -> Void
    let onRestore: () -> Void
    let onTerms: () -> Void
    let onPrivacy: () -> Void

    var body: some View {
        VStack(spacing: PaywallStepMetrics.bottomDockSpacing) {
            PaywallTrustRow(colorScheme: colorScheme)
                .frame(maxWidth: .infinity)

            PaywallCTABlock(
                title: ctaTitle,
                package: package,
                colorScheme: colorScheme,
                isEnabled: isEnabled,
                action: onCTA
            )

            PaywallFooterLinks(
                colorScheme: colorScheme,
                onRestore: onRestore,
                onTerms: onTerms,
                onPrivacy: onPrivacy
            )
        }
        .padding(.horizontal, PaywallStepMetrics.bottomDockHorizontalPadding)
    }
}

/// Primary CTA with pricing subtext (e.g. "then just $44.99 per year ($0.94/week)").
private struct PaywallCTABlock: View {
    let title: String
    let package: Package?
    let colorScheme: ColorScheme
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            PaywallPrimaryButton(
                title: title,
                isEnabled: isEnabled,
                fontSize: PaywallStep3Metrics.ctaSize,
                action: action
            )

            if let package {
                Text(PaywallPricingFormatter.priceSubtitle(for: package))
                    .font(ForeverFont.body(size: PaywallStep3Metrics.ctaSubtextSize, relativeTo: .footnote))
                    .foregroundStyle(PaywallTheme.ctaSubtext(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct PaywallTrustRow: View {
    let colorScheme: ColorScheme
    var labelSize: CGFloat = 17

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(PaywallTheme.trustGreen)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text("No Payment Due Now")
                .font(ForeverFont.bold(size: labelSize, relativeTo: .headline))
                .foregroundStyle(PaywallTheme.primaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct PaywallPrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    var fontSize: CGFloat = 17
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ForeverFont.cta(size: fontSize, relativeTo: .headline))
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
        .font(ForeverFont.footnote())
        .foregroundStyle(PaywallTheme.footerLink(for: colorScheme))
    }
}

private struct PaywallErrorBanner: View {
    let message: String
    var isInformational: Bool = false
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Text(message)
                .font(ForeverFont.footnote())
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

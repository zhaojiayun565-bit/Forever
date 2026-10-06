import Foundation
import RevenueCat

/// A free trial the user is eligible for, derived from the StoreKit intro offer.
struct PaywallTrial: Equatable {
    let period: SubscriptionPeriod

    /// Hyphenated duration for headlines, e.g. "7-day" or "1-month".
    var durationLabel: String {
        switch period.unit {
        case .day: "\(period.value)-day"
        case .week: "\(period.value * 7)-day"
        case .month: "\(period.value)-month"
        case .year: "\(period.value)-year"
        @unknown default: "free"
        }
    }

    /// Spoken duration for sentences, e.g. "7 days" or "1 month".
    var durationPhrase: String {
        let (count, unit): (Int, String) = switch period.unit {
        case .day: (period.value, "day")
        case .week: (period.value * 7, "day")
        case .month: (period.value, "month")
        case .year: (period.value, "year")
        @unknown default: (period.value, "day")
        }
        return "\(count) \(unit)\(count == 1 ? "" : "s")"
    }

    /// Calendar date the first payment is taken if the user doesn't cancel.
    var billingDate: Date {
        var components = DateComponents()
        switch period.unit {
        case .day: components.day = period.value
        case .week: components.day = period.value * 7
        case .month: components.month = period.value
        case .year: components.year = period.value
        @unknown default: components.day = period.value
        }
        return Calendar.current.date(byAdding: components, to: Date()) ?? Date()
    }

    /// Whole days until billing, used for the timeline labels.
    var daysUntilBilling: Int {
        max(1, Calendar.current.dateComponents([.day], from: Date(), to: billingDate).day ?? 1)
    }
}

/// Formats RevenueCat package prices for the custom paywall UI.
enum PaywallPricingFormatter {
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// Subtext under the CTA: billed amount first, then auto-renew terms (trial-aware).
    static func priceSubtitle(for package: Package, trial: PaywallTrial?) -> String {
        let product = package.storeProduct
        let priceText = product.localizedPriceString

        guard let period = product.subscriptionPeriod else {
            return "\(priceText) one-time purchase"
        }

        var billed = "\(priceText) per \(unitName(period.unit))"
        if period.unit == .year, let weekly = formatCurrency(product.price / 52, currencyCode: product.currencyCode) {
            billed += " (\(weekly)/week)"
        }
        guard let trial else { return "\(billed). Renews automatically, cancel anytime." }
        return "Free for \(trial.durationPhrase), then \(billed). Cancel anytime."
    }

    /// Billed amount for plan cards, e.g. "$79.99/yr" (the most prominent price, per App Review 3.1.2).
    static func planCardPriceLabel(for package: Package) -> String {
        let product = package.storeProduct
        guard let period = product.subscriptionPeriod else { return product.localizedPriceString }
        return "\(product.localizedPriceString)/\(shortUnitName(period.unit))"
    }

    /// Secondary monthly equivalent for yearly cards, e.g. "$6.67/mo".
    static func planCardSecondaryLabel(for package: Package) -> String? {
        let product = package.storeProduct
        guard product.subscriptionPeriod?.unit == .year,
              let monthly = formatCurrency(product.price / 12, currencyCode: product.currencyCode) else { return nil }
        return "\(monthly)/mo"
    }

    /// "SAVE 40%" computed from real prices; nil when yearly isn't cheaper than 12 months.
    static func yearlySavingsBadge(yearly: Package?, monthly: Package?) -> String? {
        guard let yearly = yearly?.storeProduct, let monthly = monthly?.storeProduct,
              yearly.subscriptionPeriod?.unit == .year, monthly.subscriptionPeriod?.unit == .month else { return nil }
        let annualizedMonthly = (monthly.price as NSDecimalNumber).doubleValue * 12
        guard annualizedMonthly > 0 else { return nil }
        let savings = Int((1 - (yearly.price as NSDecimalNumber).doubleValue / annualizedMonthly) * 100)
        return savings >= 5 ? "SAVE \(savings)%" : nil
    }

    /// Billing date copy for the trial timeline.
    static func billingStartDate(for trial: PaywallTrial) -> String {
        trial.billingDate.formatted(date: .abbreviated, time: .omitted)
    }

    /// Purchase CTA, only mentioning a trial when the user will actually get one.
    static func purchaseCTATitle(trial: PaywallTrial?) -> String {
        guard let trial else { return "Subscribe" }
        return "Start my \(trial.durationLabel) free trial"
    }

    private static func unitName(_ unit: SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        case .year: "year"
        @unknown default: "period"
        }
    }

    private static func shortUnitName(_ unit: SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day: "day"
        case .week: "wk"
        case .month: "mo"
        case .year: "yr"
        @unknown default: "period"
        }
    }

    private static func formatCurrency(_ amount: Decimal, currencyCode: String?) -> String? {
        if let currencyCode {
            currencyFormatter.currencyCode = currencyCode
        }
        return currencyFormatter.string(from: amount as NSDecimalNumber)
    }
}

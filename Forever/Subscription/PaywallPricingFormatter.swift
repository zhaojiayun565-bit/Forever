import Foundation
import RevenueCat

/// Formats RevenueCat package prices for the custom paywall UI.
enum PaywallPricingFormatter {
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// Subtext under the offer CTA (e.g. annual price + weekly equivalent).
    static func priceSubtitle(for package: Package) -> String {
        let product = package.storeProduct
        let priceText = product.localizedPriceString

        guard let period = product.subscriptionPeriod else {
            return "then just \(priceText)"
        }

        switch period.unit {
        case .year:
            let weekly = formattedWeeklyEquivalent(from: product.price, currencyCode: product.currencyCode)
            if let weekly {
                return "then just \(priceText) per year (\(weekly)/week)"
            }
            return "then just \(priceText) per year"
        case .month:
            return "then just \(priceText) per month"
        case .week:
            return "then just \(priceText) per week"
        default:
            return "then just \(priceText)"
        }
    }

    /// Short price label for plan cards (e.g. "$4.17/mo" for yearly).
    static func planCardPriceLabel(for package: Package) -> String {
        let product = package.storeProduct
        let price = product.localizedPriceString

        guard let period = product.subscriptionPeriod else {
            return price
        }

        switch period.unit {
        case .year:
            let monthly = product.price / 12
            if let monthlyText = formatCurrency(monthly, currencyCode: product.currencyCode) {
                return "\(monthlyText)/mo"
            }
            return "\(price)/yr"
        case .month:
            return "\(price)/mo"
        case .week:
            return "\(price)/wk"
        default:
            return price
        }
    }

    /// Billing date copy for timeline step 3.
    static func billingStartDate(trialDays: Int = 7) -> String {
        guard let date = Calendar.current.date(byAdding: .day, value: trialDays, to: Date()) else {
            return "your trial ends"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    /// Badge text for free trial on yearly plan (always shown; falls back to trialDays).
    static func freeTrialBadgeText(for package: Package?, trialDays: Int = 7) -> String {
        if let package,
           let intro = package.storeProduct.introductoryDiscount,
           intro.paymentMode == .freeTrial {
            let days = intro.subscriptionPeriod.value
            let unit = intro.subscriptionPeriod.unit
            switch unit {
            case .day where days > 0:
                return "\(days) DAYS FREE"
            case .week where days > 0:
                return "\(days * 7) DAYS FREE"
            default:
                break
            }
        }
        return "\(trialDays) DAYS FREE"
    }

    static func purchaseCTATitle(trialDays: Int = 7) -> String {
        "Start my \(trialDays)-day FREE trial"
    }

    private static func formatCurrency(_ amount: Decimal, currencyCode: String?) -> String? {
        if let currencyCode {
            currencyFormatter.currencyCode = currencyCode
        }
        return currencyFormatter.string(from: amount as NSDecimalNumber)
    }

    private static func formattedWeeklyEquivalent(from annualPrice: Decimal, currencyCode: String?) -> String? {
        formatCurrency(annualPrice / 52, currencyCode: currencyCode)
    }
}

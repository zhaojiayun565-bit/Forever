import Foundation
import Observation
import RevenueCat

/// Owns RevenueCat customer info, offerings, purchases, and Pro entitlement state.
@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    private(set) var customerInfo: CustomerInfo?
    private(set) var offerings: Offerings?
    private(set) var isLoading = false
    var lastErrorMessage: String?

    /// Active Pro entitlement (Forever: App for Couples Pro).
    var isPro: Bool {
        customerInfo?.entitlements[RevenueCatConfiguration.proEntitlementID]?.isActive == true
    }

    var activeProExpirationDate: Date? {
        customerInfo?
            .entitlements[RevenueCatConfiguration.proEntitlementID]?
            .expirationDate
    }

    var currentOffering: Offering? {
        if let id = RevenueCatConfiguration.defaultOfferingID {
            return offerings?.offering(identifier: id)
        }
        return offerings?.current
    }

    private var customerInfoTask: Task<Void, Never>?

    private init() {}

    /// Configures the SDK once at launch. Safe to call multiple times.
    static func configure() {
        #if DEBUG
        Purchases.logLevel = .debug
        #endif
        Purchases.configure(withAPIKey: RevenueCatConfiguration.apiKey)
    }

    /// Starts listening for customer-info updates and loads offerings.
    func start() {
        guard customerInfoTask == nil else { return }
        customerInfoTask = Task { [weak self] in
            guard let self else { return }
            for await info in Purchases.shared.customerInfoStream {
                await MainActor.run {
                    self.customerInfo = info
                    self.lastErrorMessage = nil
                }
            }
        }
        Task { await refresh() }
    }

    /// Links the RevenueCat customer to the signed-in Supabase user.
    func syncUserID(_ userID: String?) async {
        do {
            if let userID {
                let result = try await Purchases.shared.logIn(userID)
                customerInfo = result.customerInfo
            } else {
                customerInfo = try await Purchases.shared.logOut()
            }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Fetches the latest customer info and offerings.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let info = Purchases.shared.customerInfo()
            async let offers = Purchases.shared.offerings()
            customerInfo = try await info
            offerings = try await offers
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    /// Purchases a package from the current offering.
    func purchase(_ package: Package) async throws -> CustomerInfo {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled {
                throw SubscriptionError.purchaseCancelled
            }
            customerInfo = result.customerInfo
            lastErrorMessage = nil
            return result.customerInfo
        } catch let error as SubscriptionError {
            lastErrorMessage = error.localizedDescription
            throw error
        } catch {
            lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    /// Restores previous App Store purchases.
    func restorePurchases() async throws -> CustomerInfo {
        isLoading = true
        defer { isLoading = false }
        do {
            let info = try await Purchases.shared.restorePurchases()
            customerInfo = info
            lastErrorMessage = nil
            return info
        } catch {
            lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    /// Package for a product or package identifier in the current offering.
    func package(for productID: String) -> Package? {
        currentOffering?.availablePackages.first {
            $0.identifier == productID || $0.storeProduct.productIdentifier == productID
        }
    }

    var monthlyPackage: Package? {
        package(for: RevenueCatConfiguration.ProductID.monthly) ?? currentOffering?.monthly
    }

    var yearlyPackage: Package? {
        package(for: RevenueCatConfiguration.ProductID.yearly) ?? currentOffering?.annual
    }

    /// Best package for the hard paywall (yearly trial preferred).
    var preferredTrialPackage: Package? {
        yearlyPackage ?? currentOffering?.availablePackages.first
    }

    /// Clears the last surfaced error (e.g. after user dismisses banner).
    func clearLastError() {
        lastErrorMessage = nil
    }
}

enum SubscriptionError: LocalizedError {
    case purchaseCancelled
    case noOffering
    case packageNotFound

    var errorDescription: String? {
        switch self {
        case .purchaseCancelled:
            return "Purchase was cancelled."
        case .noOffering:
            return "No subscription offering is available right now. Please try again later."
        case .packageNotFound:
            return "That plan is not available."
        }
    }
}

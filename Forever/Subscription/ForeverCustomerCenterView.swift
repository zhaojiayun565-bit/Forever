import RevenueCatUI
import SwiftUI

/// Subscription management UI (cancel, change plan, restore) via RevenueCat Customer Center.
struct ForeverCustomerCenterView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CustomerCenterView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

extension View {
    /// Presents RevenueCat Customer Center in a sheet.
    func foreverCustomerCenter(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            ForeverCustomerCenterView()
        }
    }
}

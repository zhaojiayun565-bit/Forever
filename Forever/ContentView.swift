import SwiftUI

struct ContentView: View {
    @Environment(AppStateManager.self) private var state
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                // State 0: App Store Onboarding
                OnboardingView()
            } else if state.isLoading {
                // Loading State
                ProgressView()
            } else if state.currentUser == nil {
                // State 1: Not Logged In
                LoginView()
            } else if state.currentCouple == nil {
                // State 2: Logged in, but no partner paired
                PairingView()
            } else {
                // State 3: Fully paired
                TabView {
                    HomeDashboardView()
                        .tabItem { Label("Us", systemImage: "heart.fill") }

                    MapDashboardView()
                        .tabItem { Label("Map", systemImage: "map.fill") }

                    ArchiveView()
                        .tabItem { Label("Archive", systemImage: "square.grid.2x2.fill") }

                    SettingsView()
                        .tabItem { Label("Me", systemImage: "person.circle.fill") }
                }
                .tint(.pink)
            }
        }
        .task {
            await state.initializeApp()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Self-Healing Widget Sync
            if newPhase == .active && state.currentCouple != nil {
                Task { await state.loadPartnerProfile() }
            }
        }
    }
}

import SwiftUI

struct ContentView: View {
    @Environment(AppStateManager.self) private var state
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        Group {
            if state.isLoading {
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

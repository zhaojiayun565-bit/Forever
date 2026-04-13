import SwiftUI

struct ContentView: View {
    @Environment(AppStateManager.self) private var state
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        Group {
            switch (state.isLoading, state.currentCouple != nil) {
            case (true, _):
                ProgressView()
            case (false, true):
                TabView {
                    HomeDashboardView()
                        .tabItem { Label("Us", systemImage: "heart.fill") }
                    
                    ArchiveView()
                        .tabItem { Label("Archive", systemImage: "square.grid.2x2.fill") }
                    
                    SettingsView()
                        .tabItem { Label("Me", systemImage: "person.circle.fill") }
                }
                .tint(.pink) // Capwords style accent
            case (false, false):
                PairingView()
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

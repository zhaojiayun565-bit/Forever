import SwiftUI
import UserNotifications

struct ContentView: View {
    @Environment(AppStateManager.self) private var state
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSkippedPairing") private var hasSkippedPairing = false
    @Environment(\.scenePhase) var scenePhase
    @State private var showDrawingBoard = false
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView {
                    withAnimation(.smooth(duration: 0.55)) {
                        showSplash = false
                    }
                }
                .zIndex(1)
                .transition(.opacity)
            } else {
                mainContent
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .task {
            await state.initializeApp()
            await registerForPushIfAuthorized()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && state.currentCouple != nil {
                Task {
                    await state.syncAndRefreshWidgets()
                    await state.loadMemories()
                }
            }
        }
        .fullScreenCover(isPresented: $showDrawingBoard) {
            LockscreenDrawingBoardView()
                .environment(state)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDrawingBoard)) { _ in
            if state.currentCouple != nil { showDrawingBoard = true }
        }
        .onOpenURL { url in
            if url.host == "drawingboard", state.currentCouple != nil {
                showDrawingBoard = true
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if !hasCompletedOnboarding {
            OnboardingView()
        } else if state.isLoading {
            ProgressView()
        } else if state.currentUser == nil {
            LoginView()
        } else if state.currentCouple == nil && !hasSkippedPairing {
            PairingView()
        } else {
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

    /// Re-registers for remote notifications on launch when the user already granted permission.
    private func registerForPushIfAuthorized() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }
}

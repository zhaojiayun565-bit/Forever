import SwiftUI
import UserNotifications

enum AppTab: Hashable {
    case home, map, questions, me
}

struct ContentView: View {
    @Environment(AppStateManager.self) private var state
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSkippedPairing") private var hasSkippedPairing = false
    @Environment(\.scenePhase) var scenePhase
    @State private var showDrawingBoard = false
    @State private var showSplash = true
    @State private var selectedTab: AppTab = .home

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
        .onReceive(NotificationCenter.default.publisher(for: .openHome)) { _ in
            selectedTab = .home
        }
        .onReceive(NotificationCenter.default.publisher(for: .openQuestions)) { _ in
            selectedTab = .questions
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
            TabView(selection: $selectedTab) {
                HomeDashboardView()
                    .tag(AppTab.home)
                    .tabItem { Label("Us", systemImage: "heart.fill") }

                MapDashboardView()
                    .tag(AppTab.map)
                    .tabItem { Label("Map", systemImage: "map.fill") }

                DiscoverQuestionsView()
                    .tag(AppTab.questions)
                    .tabItem { Label("Questions", systemImage: "sparkles") }

                SettingsView()
                    .tag(AppTab.me)
                    .tabItem { Label("Me", systemImage: "person.circle.fill") }
            }
            .tint(.pink)
        }
    }

    /// Re-registers for remote notifications on launch when the user granted full or provisional permission.
    private func registerForPushIfAuthorized() async {
        await NotificationAuthorizationManager.registerForRemoteIfEligible()
    }
}

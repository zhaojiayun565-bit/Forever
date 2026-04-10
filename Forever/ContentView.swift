//
//  ContentView.swift
//  Forever
//
//  Created by Jia Yun Zhao on 2026-04-02.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppStateManager.self) private var state
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch (state.isLoading, state.currentCouple != nil) {
            case (true, _):
                ProgressView()
            case (false, true):
                HomeDashboardView()
            case (false, false):
                PairingView()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await state.loadPartnerProfile()
                }
            }
        }
        .task {
            await state.initializeApp()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppStateManager())
}

//
//  ContentView.swift
//  Forever
//
//  Created by Jia Yun Zhao on 2026-04-02.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppStateManager.self) private var state

    var body: some View {
        Group {
            switch (state.isLoading, state.currentCouple != nil) {
            case (true, _):
                ProgressView()
            case (false, true):
                Text("Main Dashboard")
            case (false, false):
                PairingView()
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

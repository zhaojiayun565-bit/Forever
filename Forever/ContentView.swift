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
                VStack(spacing: 20) {
                    Text("Main Dashboard")
                        .font(.largeTitle.bold())
                    
                    Button("Draw a Note for Partner") {
                        // You can make this open a sheet
                    }
                    // Alternatively, just put DrawingView() here directly to test it!
                    DrawingView()
                }
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

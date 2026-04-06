//
//  ForeverApp.swift
//  Forever
//
//  Created by Jia Yun Zhao on 2026-04-02.
//

import SwiftUI

@main
struct ForeverApp: App {
    // INJECT THE APP DELEGATE HERE
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var appState = AppStateManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}

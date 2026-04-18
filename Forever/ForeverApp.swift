//
//  ForeverApp.swift
//  Forever
//
//  Created by Jia Yun Zhao on 2026-04-02.
//

import Kingfisher
import SwiftUI

@main
struct ForeverApp: App {
    // INJECT THE APP DELEGATE HERE
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var appState = AppStateManager()

    init() {
        let cache = ImageCache.default
        cache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024
        cache.diskStorage.config.sizeLimit = 250 * 1024 * 1024
        cache.diskStorage.config.expiration = .days(30)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}

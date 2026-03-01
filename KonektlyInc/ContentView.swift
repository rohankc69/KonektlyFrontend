//
//  ContentView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct ContentView: View {
    @State private var showingSplash = true
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        ZStack {
            if showingSplash {
                SplashScreenView(isActive: $showingSplash)
            } else {
                AppRootView()
                    .environmentObject(authStore)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: showingSplash)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthStore.shared)
}

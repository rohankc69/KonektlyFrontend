//
//  AppRootView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct AppRootView: View {
    // Session-only flag: role picker shows once per cold launch
    @State private var hasPickedRole = false
    @State private var selectedTab = 0

    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        Group {
            if !hasPickedRole {
                // 1. Role picker - always the first screen after splash
                RolePickerView(hasCompletedOnboarding: $hasPickedRole)
            } else if !authStore.isAuthenticated {
                // 2. Phone login / OTP
                PhoneLoginView()
            } else if authStore.needsEmailVerification && !authStore.needsProfile {
                // 3. Email verification (soft gate - can skip if profile still needed)
                NavigationStack {
                    EmailVerificationView()
                }
            } else if authStore.needsProfile {
                // 4. Profile creation
                profileCreationView
            } else {
                // 5. Main app tabs
                mainTabView
            }
        }
        .onOpenURL { url in
            // Handle email verification deep links
            // konektly://verify-email?token=<token>
            if url.host == "verify-email",
               let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                   .queryItems?.first(where: { $0.name == "token" })?.value {
                Task { try? await authStore.verifyEmailToken(token) }
            }
        }
    }

    // MARK: - Profile Creation (role-aware)

    @ViewBuilder
    private var profileCreationView: some View {
        let roleRaw = UserDefaults.standard.string(forKey: "userRole") ?? UserRole.worker.rawValue
        let role = UserRole(rawValue: roleRaw) ?? .worker
        NavigationStack {
            if role == .worker {
                WorkerProfileCreateView()
            } else {
                BusinessProfileCreateView()
            }
        }
    }

    // MARK: - Main Tab View

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            MapHomeView()
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(0)

            ShiftsView()
                .tabItem { Label("Shifts", systemImage: "briefcase.fill") }
                .tag(1)

            MessagesView()
                .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(2)

            // Verification status replaces plain profile tab - user can still edit profile from within
            VerificationStatusView()
                .tabItem { Label("Account", systemImage: "person.fill") }
                .tag(3)
        }
        .tint(Theme.Colors.primary)
    }
}

#Preview {
    AppRootView()
        .environmentObject(AuthStore.shared)
}

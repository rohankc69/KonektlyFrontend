//
//  AppRootView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct AppRootView: View {
    @State private var hasPickedRole = false
    @State private var selectedTab = 0

    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        Group {
            if !hasPickedRole {
                // Step 1: Role picker - must select worker/business before login
                RolePickerView(hasCompletedOnboarding: $hasPickedRole)
            } else if !authStore.isAuthenticated {
                // Step 2: Phone login + OTP
                PhoneLoginView()
            } else {
                // Steps 3-7: Authenticated - route based on backend state
                authenticatedFlow
            }
        }
        .onOpenURL { url in
            if url.host == "verify-email",
               let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                   .queryItems?.first(where: { $0.name == "token" })?.value {
                Task { try? await authStore.verifyEmailToken(token) }
            }
        }
    }

    // MARK: - Authenticated Flow

    @ViewBuilder
    private var authenticatedFlow: some View {
        switch authStore.onboardingStep {
        case .email:
            // Step 3: Email verification
            NavigationStack {
                EmailVerificationView()
            }

        case .name:
            // Step 4: Name entry
            NavigationStack {
                NameEntryView()
            }

        case .terms:
            // Step 5: Terms acceptance
            NavigationStack {
                TermsAcceptView()
            }

        case .profileDetails:
            // Step 6: Gov ID / Business details
            NavigationStack {
                profileCreationView
            }

        case .complete:
            // Step 7: Main dashboard
            mainTabView
        }
    }

    // MARK: - Profile Creation (role-aware)

    @ViewBuilder
    private var profileCreationView: some View {
        if authStore.selectedRole == .worker {
            WorkerProfileCreateView()
        } else {
            BusinessProfileCreateView()
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

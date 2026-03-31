//
//  AppRootView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct AppRootView: View {
    @AppStorage("hasPickedRole") private var hasPickedRole = false
    @State private var selectedTab = 0

    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var messageStore: MessageStore
    @EnvironmentObject private var jobStore: JobStore

    var body: some View {
        Group {
            if !hasPickedRole {
                // 1. Role picker - must select worker/business before login
                RolePickerView(hasCompletedOnboarding: $hasPickedRole)
            } else if !authStore.isAuthenticated {
                // 2. Phone login / OTP (role already selected, sent with verify-otp)
                PhoneLoginView()
            } else {
                // 3. Authenticated - route based on onboarding step
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
        // Reset tab to Home when user logs in/out
        .onChange(of: authStore.isAuthenticated) { _, isAuth in
            if isAuth {
                selectedTab = 0
            }
        }
    }

    // MARK: - Authenticated Flow

    @ViewBuilder
    private var authenticatedFlow: some View {
        switch authStore.onboardingStep {
        case .name:
            NavigationStack { NameEntryView() }
        case .dob:
            NavigationStack { DOBEntryView() }
        case .terms:
            NavigationStack { TermsAcceptView() }
        case .privacy:
            NavigationStack { PrivacyAcceptView() }
        case .profileDetails:
            NavigationStack { profileCreationView }
        case .complete:
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
                .badge(messageStore.totalUnreadCount)

            VerificationStatusView()
                .tabItem { Label("Account", systemImage: "person.fill") }
                .tag(3)
        }
        .tint(Theme.Colors.primary)
        .onChange(of: messageStore.pendingDeepLinkConversationId) { _, newId in
            if newId != nil {
                selectedTab = 2
            }
        }
        .onChange(of: jobStore.pendingDeepLinkJobId) { _, newId in
            if newId != nil {
                selectedTab = 0
            }
        }
        .task {
            // Pre-fetch applications so map can show applied markers immediately
            if authStore.selectedRole == .worker {
                await jobStore.fetchMyApplications()
            }
        }
    }
}

#Preview {
    AppRootView()
        .environmentObject(AuthStore.shared)
}

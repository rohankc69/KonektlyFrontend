//
//  PrivacyPolicyView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-25.
//
//  Two views:
//  1. PrivacyAcceptView — onboarding step, requires scroll + accept
//  2. PrivacyReadView  — read-only from Settings
//

import SwiftUI

// MARK: - Privacy Accept View (Onboarding)

struct PrivacyAcceptView: View {
    @EnvironmentObject private var authStore: AuthStore

    @State private var privacy: PrivacyDocument?
    @State private var isFetching = true
    @State private var fetchError: String?
    @State private var hasScrolledToBottom = false
    @State private var hasAgreed = false
    @State private var isAccepting = false
    @State private var acceptError: String?

    var body: some View {
        VStack(spacing: 0) {
            if isFetching {
                Spacer()
                VStack(spacing: Theme.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading Privacy Policy…")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                Spacer()

            } else if let error = fetchError {
                Spacer()
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 36))
                        .foregroundColor(Theme.Colors.tertiaryText)
                    Text(error)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                    Button("Try Again") { Task { await fetchPrivacy() } }
                        .font(Theme.Typography.subheadline.weight(.semibold))
                        .foregroundColor(Theme.Colors.primary)
                }
                Spacer()

            } else if let privacy {
                contentView(privacy: privacy)
            }
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
        .task { await fetchPrivacy() }
    }

    @ViewBuilder
    private func contentView(privacy: PrivacyDocument) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 36))
                        .foregroundColor(Theme.Colors.primaryText)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(privacy.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.Colors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Effective \(privacy.effectiveDate)  ·  v\(privacy.version)")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.tertiaryText)
                    }
                }
                .padding(.top, Theme.Spacing.xxl)

                Text(privacy.content)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let error = acceptError {
                    Text(error)
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.error)
                }

                Color.clear
                    .frame(height: 1)
                    .onAppear { hasScrolledToBottom = true }
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }

        VStack(spacing: Theme.Spacing.lg) {
            if !hasScrolledToBottom {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Scroll to read the full policy before agreeing")
                        .font(Theme.Typography.caption)
                }
                .foregroundColor(Theme.Colors.tertiaryText)
            }

            Button(action: {
                guard hasScrolledToBottom else { return }
                hasAgreed.toggle()
            }) {
                HStack {
                    Text("I Accept")
                        .font(Theme.Typography.body)
                        .foregroundColor(
                            hasScrolledToBottom
                                ? Theme.Colors.primaryText
                                : Theme.Colors.tertiaryText
                        )
                    Spacer()
                    Image(systemName: hasAgreed ? "checkmark.square.fill" : "square")
                        .font(.system(size: 24))
                        .foregroundColor(
                            hasAgreed ? Theme.Colors.accent :
                            hasScrolledToBottom ? Theme.Colors.border : Theme.Colors.tertiaryText
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(!hasScrolledToBottom)

            OnboardingBottomBar(
                onBack: { authStore.signOut() },
                onNext: { accept(version: privacy.version) },
                isLoading: isAccepting,
                isEnabled: hasAgreed && hasScrolledToBottom
            )
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.sm)
    }

    private func fetchPrivacy() async {
        isFetching = true
        fetchError = nil
        defer { isFetching = false }
        do {
            let doc: PrivacyDocument = try await APIClient.shared.publicRequest(.currentPrivacy)
            privacy = doc
        } catch let appError as AppError {
            fetchError = appError.errorDescription
        } catch {
            fetchError = AppError.network(underlying: error).errorDescription
        }
    }

    private func accept(version: String) {
        guard hasAgreed else { return }
        isAccepting = true
        acceptError = nil
        Task {
            defer { isAccepting = false }
            do {
                try await authStore.acceptPrivacy(version: version)
            } catch let appError as AppError {
                acceptError = appError.errorDescription
            } catch {
                acceptError = AppError.network(underlying: error).errorDescription
            }
        }
    }
}

// MARK: - Privacy Read View (Settings — read-only)

struct PrivacyReadView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var privacy: PrivacyDocument?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.Colors.primaryText)
                        .frame(width: 40, height: 40)
                        .background(Theme.Colors.inputBackground)
                        .clipShape(Circle())
                }

                Spacer()

                Text("Privacy Policy")
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.primaryText)

                Spacer()

                Color.clear
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)

            Divider()

            if isLoading {
                Spacer()
                VStack(spacing: Theme.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading Privacy Policy…")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                Spacer()

            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 36))
                        .foregroundColor(Theme.Colors.tertiaryText)
                    Text(error)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.xl)
                    Button("Try Again") {
                        Task { await fetchPrivacy() }
                    }
                    .font(Theme.Typography.subheadline.weight(.semibold))
                    .foregroundColor(Theme.Colors.primaryText)
                }
                Spacer()

            } else if let privacy {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(privacy.title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Theme.Colors.primaryText)

                            Text("Effective \(privacy.effectiveDate)  ·  v\(privacy.version)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.tertiaryText)
                        }

                        Divider()

                        Text(privacy.content)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                    }
                    .padding(Theme.Spacing.xl)
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
        .task { await fetchPrivacy() }
    }

    private func fetchPrivacy() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let doc: PrivacyDocument = try await APIClient.shared.publicRequest(.currentPrivacy)
            privacy = doc
        } catch let appError as AppError {
            errorMessage = appError.errorDescription
        } catch {
            errorMessage = AppError.network(underlying: error).errorDescription
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyAcceptView()
            .environmentObject(AuthStore.shared)
    }
}

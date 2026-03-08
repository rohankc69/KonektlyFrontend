//
//  TermsAcceptView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-03.
//

import SwiftUI

struct TermsAcceptView: View {
    @EnvironmentObject private var authStore: AuthStore

    // MARK: - State

    /// Live document fetched from GET /api/v1/legal/terms/
    @State private var terms: TermsDocument? = nil
    @State private var isFetchingTerms = true
    @State private var fetchError: String? = nil

    /// Scroll gate — "I Agree" only unlocks after user reaches the bottom
    @State private var hasScrolledToBottom = false
    @State private var hasAgreed = false

    /// Accept flow
    @State private var isAccepting = false
    @State private var acceptError: String? = nil

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if isFetchingTerms {
                // Loading state — centered spinner, same background as every onboarding screen
                Spacer()
                VStack(spacing: Theme.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading Terms…")
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                Spacer()

            } else if let error = fetchError {
                // Fetch failed — retry
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
                    Button("Try Again") { Task { await fetchTerms() } }
                        .font(Theme.Typography.subheadline.weight(.semibold))
                        .foregroundColor(Theme.Colors.primary)
                }
                Spacer()

            } else if let terms {
                // Live content
                contentView(terms: terms)
            }
        }
        .background(Theme.Colors.background)
        .navigationBarHidden(true)
        .task { await fetchTerms() }
    }

    // MARK: - Content (shown after successful fetch)

    @ViewBuilder
    private func contentView(terms: TermsDocument) -> some View {
        // Scroll view with a sentinel at the bottom to detect when the user reaches the end
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {

                // Header — matches every other onboarding screen
                HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 36))
                        .foregroundColor(Theme.Colors.primaryText)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(terms.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(Theme.Colors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Effective \(terms.effectiveDate)  ·  v\(terms.version)")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.tertiaryText)
                    }
                }
                .padding(.top, Theme.Spacing.xxl)

                // Live terms content
                Text(terms.content)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                // Accept error (if POST /auth/terms/accept/ failed)
                if let error = acceptError {
                    Text(error)
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.error)
                }

                // Scroll sentinel — when this appears on screen, unlock the checkbox
                Color.clear
                    .frame(height: 1)
                    .onAppear { hasScrolledToBottom = true }
            }
            .padding(.horizontal, Theme.Spacing.xl)
        }

        // Bottom section — same layout as every onboarding screen
        VStack(spacing: Theme.Spacing.lg) {
            // Scroll hint — shown until user reaches bottom
            if !hasScrolledToBottom {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Scroll to read all terms before agreeing")
                        .font(Theme.Typography.caption)
                }
                .foregroundColor(Theme.Colors.tertiaryText)
            }

            // I Agree checkbox
            Button(action: {
                guard hasScrolledToBottom else { return }
                hasAgreed.toggle()
            }) {
                HStack {
                    Text("I Agree")
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
                onNext: { accept(version: terms.version) },
                isLoading: isAccepting,
                isEnabled: hasAgreed && hasScrolledToBottom
            )
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.sm)
    }

    // MARK: - Network

    private func fetchTerms() async {
        isFetchingTerms = true
        fetchError = nil
        defer { isFetchingTerms = false }

        do {
            // Public endpoint — no auth header needed
            let doc: TermsDocument = try await APIClient.shared.publicRequest(.currentTerms)
            terms = doc
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
                try await authStore.acceptTerms(version: version)
            } catch let appError as AppError {
                acceptError = appError.errorDescription
            } catch {
                acceptError = AppError.network(underlying: error).errorDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        TermsAcceptView()
            .environmentObject(AuthStore.shared)
    }
}

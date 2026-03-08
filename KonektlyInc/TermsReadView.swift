//
//  TermsReadView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-08.
//
//  Read-only view of the live Terms & Conditions document.
//  Accessed from Profile → Terms & Conditions.
//  No accept action — user already accepted during onboarding.
//

import SwiftUI

struct TermsReadView: View {

    // MARK: - State

    @Environment(\.dismiss) private var dismiss

    @State private var terms: TermsDocument? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // Nav bar — back arrow + title, consistent with app style
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

                Text("Terms & Conditions")
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.primaryText)

                Spacer()

                // Invisible spacer to keep title centred
                Color.clear
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.md)

            Divider()

            // Content area
            if isLoading {
                Spacer()
                VStack(spacing: Theme.Spacing.lg) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading Terms…")
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
                        Task { await fetchTerms() }
                    }
                    .font(Theme.Typography.subheadline.weight(.semibold))
                    .foregroundColor(Theme.Colors.primaryText)
                }
                Spacer()

            } else if let terms {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {

                        // Title + metadata
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(terms.title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Theme.Colors.primaryText)

                            Text("Effective \(terms.effectiveDate)  ·  v\(terms.version)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.tertiaryText)
                        }

                        Divider()

                        // Full terms content
                        Text(terms.content)
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
        .task { await fetchTerms() }
    }

    // MARK: - Fetch

    private func fetchTerms() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let doc: TermsDocument = try await APIClient.shared.publicRequest(.currentTerms)
            terms = doc
        } catch let appError as AppError {
            errorMessage = appError.errorDescription
        } catch {
            errorMessage = AppError.network(underlying: error).errorDescription
        }
    }
}

#Preview {
    TermsReadView()
}

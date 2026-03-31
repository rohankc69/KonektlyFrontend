//
//  UpgradeView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct UpgradeView: View {
    let price: String
    let isPurchasing: Bool
    let isLoadingProduct: Bool
    let onPurchase: () -> Void
    let onRestore: () -> Void
    let onRetry: () -> Void

    private var isProductLoaded: Bool { !price.isEmpty }
    private var loadFailed: Bool { !isProductLoaded && !isLoadingProduct }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // MARK: - Hero
                VStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Theme.Colors.accent)
                        .padding(.bottom, Theme.Spacing.xs)

                    Text("Konektly+")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.Colors.primaryText)

                    Text("Everything you need to work smarter")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Theme.Spacing.xxxl)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xxxl)

                // MARK: - Features list (HIG grouped style)
                VStack(spacing: 0) {
                    Divider()
                    ForEach(Self.features, id: \.title) { feature in
                        HStack(spacing: Theme.Spacing.lg) {
                            Image(systemName: feature.icon)
                                .font(.system(size: Theme.Sizes.iconMedium))
                                .foregroundStyle(Theme.Colors.accent)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(feature.title)
                                    .font(Theme.Typography.bodyMedium)
                                    .foregroundStyle(Theme.Colors.primaryText)
                                Text(feature.description)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }

                            Spacer()

                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.Colors.accent)
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.vertical, Theme.Spacing.lg)
                        Divider()
                    }
                }

                // MARK: - Price
                VStack(spacing: Theme.Spacing.xs) {
                    if isProductLoaded {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(price)
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(Theme.Colors.primaryText)
                            Text("/ month")
                                .font(Theme.Typography.subheadline)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
                    } else if isLoadingProduct {
                        ProgressView()
                            .frame(height: 44)
                    } else {
                        VStack(spacing: Theme.Spacing.sm) {
                            Text("Could not load pricing")
                                .font(Theme.Typography.bodyMedium)
                                .foregroundStyle(Theme.Colors.secondaryText)
                            Button(action: onRetry) {
                                Label("Try Again", systemImage: "arrow.clockwise")
                                    .font(Theme.Typography.subheadline)
                                    .foregroundStyle(Theme.Colors.accent)
                            }
                        }
                        .frame(height: 60)
                    }
                    Text("Cancel anytime in App Store settings")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                .padding(.top, Theme.Spacing.xxxl)
                .padding(.horizontal, Theme.Spacing.xl)

                // MARK: - CTA
                VStack(spacing: Theme.Spacing.md) {
                    Button(action: onPurchase) {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(isProductLoaded ? "Subscribe Now · \(price)/mo" : "Loading…")
                        }
                    }
                    .primaryButtonStyle(isEnabled: isProductLoaded && !isPurchasing)
                    .disabled(!isProductLoaded || isPurchasing)

                    Button("Restore Purchases", action: onRestore)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.Colors.accent)
                        .frame(height: Theme.Sizes.smallButtonHeight)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xl)

                // MARK: - Legal
                Text("Subscription auto-renews monthly unless cancelled at least 24 hours before the renewal date.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.xxxl)
            }
        }
        .background(Theme.Colors.background.ignoresSafeArea())
    }

    private struct Feature {
        let icon: String
        let title: String
        let description: String
    }

    private static let features: [Feature] = [
        Feature(icon: "mappin.and.ellipse",
                title: "Exact Job Locations",
                description: "See precise addresses, not approximate areas"),
        Feature(icon: "headphones",
                title: "Priority Support",
                description: "Faster response times and dedicated service"),
        Feature(icon: "chart.line.uptrend.xyaxis",
                title: "Advanced Analytics",
                description: "Track earnings, performance and work history"),
        Feature(icon: "bolt.fill",
                title: "Early Access",
                description: "First to try new features before anyone else"),
    ]
}

#Preview {
    UpgradeView(
        price: "$9.99",
        isPurchasing: false,
        isLoadingProduct: false,
        onPurchase: {},
        onRestore: {},
        onRetry: {}
    )
}

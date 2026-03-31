//
//  PublicBusinessProfileView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-26.
//

import SwiftUI

struct PublicBusinessProfileView: View {
    let userId: Int

    @State private var profile: PublicBusinessProfile?
    @State private var reviews: [ReviewResponse] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let profile {
                ScrollView {
                    VStack(spacing: Theme.Spacing.xxl) {
                        headerSection(profile)
                        if let bio = profile.companyBio, !bio.isEmpty {
                            aboutSection(bio)
                        }
                        if !reviews.isEmpty {
                            reviewsSection
                        }
                    }
                    .padding(Theme.Spacing.xl)
                }
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "building.2")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.Colors.tertiaryText)
                    Text("Profile not available")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("Business Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }

    // MARK: - Header

    private func headerSection(_ profile: PublicBusinessProfile) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            // Logo
            if let logoUrl = profile.companyLogoUrl, let url = URL(string: logoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    businessPlaceholder
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            } else {
                businessPlaceholder
            }

            Text(profile.businessName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Theme.Colors.primaryText)

            if let status = profile.verificationStatus {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: verificationIcon(status))
                        .font(.system(size: 13))
                    Text(verificationLabel(status))
                        .font(Theme.Typography.caption)
                }
                .foregroundColor(Theme.Colors.accent)
            }

            StarRatingView(
                avgRating: profile.avgRating,
                reviewCount: profile.reviewCount ?? 0
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var businessPlaceholder: some View {
        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
            .fill(Theme.Colors.inputBackground)
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "building.2.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Theme.Colors.tertiaryText)
            )
    }

    // MARK: - About

    private func aboutSection(_ bio: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("About")
                .font(Theme.Typography.headlineSemibold)
                .foregroundColor(Theme.Colors.primaryText)

            Text(bio)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
    }

    // MARK: - Reviews

    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Reviews")
                .font(Theme.Typography.headlineSemibold)
                .foregroundColor(Theme.Colors.primaryText)

            ForEach(reviews.prefix(5), id: \.id) { review in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack {
                        InlineStarRating(avgRating: "\(review.rating)", reviewCount: 1)
                        Spacer()
                        Text(formatDate(review.createdAt))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.tertiaryText)
                    }
                    if let comment = review.comment, !comment.isEmpty {
                        Text(comment)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        async let profileReq: PublicBusinessProfile? = {
            try? await APIClient.shared.request(.publicBusinessProfile(userId: userId))
        }()

        async let reviewsReq: [ReviewResponse] = {
            let resp: ReviewsListResponse? = try? await APIClient.shared.request(.userReviews(userId: userId))
            return resp?.reviews ?? []
        }()

        let (p, r) = await (profileReq, reviewsReq)
        profile = p
        reviews = r
    }

    // MARK: - Helpers

    private func verificationIcon(_ status: String) -> String {
        switch status.lowercased() {
        case "approved", "instant_verified": return "checkmark.seal.fill"
        case "pending": return "clock.fill"
        default: return "shield.fill"
        }
    }

    private func verificationLabel(_ status: String) -> String {
        switch status.lowercased() {
        case "approved", "instant_verified": return "Verified Business"
        case "pending": return "Verification Pending"
        default: return status.capitalized
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = isoFormatter.date(from: dateString) else { return dateString }
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}

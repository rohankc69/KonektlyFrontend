//
//  PublicWorkerProfileView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-25.
//

import SwiftUI

struct PublicWorkerProfileView: View {
    let userId: Int
    @State private var profile: PublicWorkerProfile?
    @State private var reviews: [ReviewResponse] = []
    @State private var isLoading = true
    @State private var showAllReviews = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let profile {
                ScrollView {
                    VStack(spacing: Theme.Spacing.xxl) {
                        headerSection(profile)
                        statsSection(profile)
                        aboutSection(profile)
                        skillsSection(profile)
                        experienceSection(profile)
                        availabilitySection(profile)
                        reviewsSection(profile)
                    }
                    .padding(.bottom, Theme.Spacing.xxxl)
                }
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Colors.tertiaryText)
                    Text("Profile not found")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadProfile() }
    }

    // MARK: - Header

    @ViewBuilder
    private func headerSection(_ p: PublicWorkerProfile) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            // Photo
            AvatarImageView(
                previewImage: nil,
                photoURL: p.photoUrl.flatMap { URL(string: $0) },
                isUploading: false,
                size: 100
            )

            // Name + headline
            Text(p.displayName)
                .font(Theme.Typography.title1)
                .foregroundColor(Theme.Colors.primaryText)

            if let headline = p.headline, !headline.isEmpty {
                Text(headline)
                    .font(Theme.Typography.subheadline)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            // Verification badge
            HStack(spacing: Theme.Spacing.xs) {
                if p.verificationStatus == "instant_verified" || p.verificationStatus == "approved_manual" {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                    Text("Verified")
                        .font(Theme.Typography.caption)
                        .foregroundColor(.blue)
                }
            }

            // Rating
            StarRatingView(avgRating: p.avgRating, reviewCount: p.reviewCount ?? 0)
        }
        .padding(.top, Theme.Spacing.xl)
        .padding(.horizontal, Theme.Spacing.xl)
    }

    // MARK: - Stats

    @ViewBuilder
    private func statsSection(_ p: PublicWorkerProfile) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            statCard(value: "\(p.completedJobs ?? 0)", label: "Jobs Completed", icon: "briefcase.fill")
            statCard(value: "\(p.profileCompleteness ?? 0)%", label: "Profile Complete", icon: "chart.bar.fill")
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Theme.Colors.accent)
            Text(value)
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.primaryText)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    // MARK: - About

    @ViewBuilder
    private func aboutSection(_ p: PublicWorkerProfile) -> some View {
        if let bio = p.bio, !bio.isEmpty {
            sectionCard(title: "About") {
                ExpandableText(text: bio, lineLimit: 3)
            }
        } else {
            sectionCard(title: "About") {
                Text("No bio added")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
        }
    }

    // MARK: - Skills

    @ViewBuilder
    private func skillsSection(_ p: PublicWorkerProfile) -> some View {
        sectionCard(title: "Skills") {
            if let skills = p.skills, !skills.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(skills, id: \.name) { skill in
                            SkillChip(name: skill.name, proficiency: skill.proficiency)
                        }
                    }
                }
            } else {
                Text("No skills added")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
        }
    }

    // MARK: - Experience

    @ViewBuilder
    private func experienceSection(_ p: PublicWorkerProfile) -> some View {
        sectionCard(title: "Experience") {
            if let experiences = p.experiences, !experiences.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(experiences) { exp in
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            HStack {
                                Text(exp.title)
                                    .font(Theme.Typography.bodySemibold)
                                    .foregroundColor(Theme.Colors.primaryText)
                                if exp.isCurrent {
                                    Text("Current")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Theme.Colors.accent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.Colors.accent.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                            Text(exp.company)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.secondaryText)
                            Text(formatExpDateRange(start: exp.startDate, end: exp.endDate, isCurrent: exp.isCurrent))
                                .font(Theme.Typography.caption2)
                                .foregroundColor(Theme.Colors.tertiaryText)
                            if let desc = exp.description, !desc.isEmpty {
                                Text(desc)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.secondaryText)
                                    .lineLimit(2)
                            }
                        }
                        if exp.id != experiences.last?.id {
                            Divider()
                        }
                    }
                }
            } else {
                Text("No experience listed")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
        }
    }

    // MARK: - Availability

    @ViewBuilder
    private func availabilitySection(_ p: PublicWorkerProfile) -> some View {
        sectionCard(title: "Availability") {
            if let slots = p.availability, !slots.isEmpty {
                MiniAvailabilityGrid(slots: slots)
            } else {
                Text("No availability set")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
        }
    }

    // MARK: - Reviews

    @ViewBuilder
    private func reviewsSection(_ p: PublicWorkerProfile) -> some View {
        sectionCard(title: "Reviews") {
            if reviews.isEmpty {
                Text("No reviews yet")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(reviews.prefix(5)) { review in
                        reviewRow(review)
                        if review.id != reviews.prefix(5).last?.id {
                            Divider()
                        }
                    }
                    if reviews.count > 5 {
                        Button {
                            showAllReviews = true
                        } label: {
                            Text("See all \(reviews.count) reviews")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.accent)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func reviewRow(_ review: ReviewResponse) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                AvatarImageView(
                    previewImage: nil,
                    photoURL: review.reviewerPhotoUrl.flatMap { URL(string: $0) },
                    isUploading: false,
                    size: 32
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(review.reviewerDisplayName)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.primaryText)
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= review.rating ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundColor(star <= review.rating ? .yellow : Color(UIColor.systemGray4))
                        }
                    }
                }
                Spacer()
                Text(relativeDate(review.createdAt))
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
    }

    // MARK: - Helpers

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title)
                .font(Theme.Typography.headlineSemibold)
                .foregroundColor(Theme.Colors.primaryText)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let profileReq: PublicWorkerProfile = APIClient.shared.request(.publicWorkerProfile(userId: userId))
            async let reviewsReq: ReviewsListResponse = APIClient.shared.request(.userReviews(userId: userId))
            let (p, r) = try await (profileReq, reviewsReq)
            profile = p
            reviews = r.reviews
        } catch {
            print("[PROFILE] load error: \(error)")
        }
    }

    private func formatExpDateRange(start: String, end: String?, isCurrent: Bool) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let displayFmt = DateFormatter()
        displayFmt.dateFormat = "MMM yyyy"
        let startStr = fmt.date(from: start).map { displayFmt.string(from: $0) } ?? start
        if isCurrent { return "\(startStr) – Present" }
        if let end, let d = fmt.date(from: end) { return "\(startStr) – \(displayFmt.string(from: d))" }
        return startStr
    }

    private func relativeDate(_ dateString: String) -> String {
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = isoFmt.date(from: dateString) else { return dateString }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Expandable Text

struct ExpandableText: View {
    let text: String
    let lineLimit: Int
    @State private var isExpanded = false
    @State private var isTruncated = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .lineLimit(isExpanded ? nil : lineLimit)
                .background(
                    ViewThatFits(in: .vertical) {
                        Text(text)
                            .font(Theme.Typography.body)
                            .hidden()
                            .onAppear { isTruncated = false }
                        Color.clear
                            .onAppear { isTruncated = true }
                    }
                )

            if isTruncated {
                Button(isExpanded ? "Show less" : "Read more") {
                    withAnimation { isExpanded.toggle() }
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.accent)
            }
        }
    }
}

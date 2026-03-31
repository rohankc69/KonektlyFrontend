//
//  ProfileComponents.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-25.
//

import SwiftUI

// MARK: - Star Rating View

struct StarRatingView: View {
    let avgRating: String?
    let reviewCount: Int

    var body: some View {
        if reviewCount == 0 {
            Text("No reviews yet")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.tertiaryText)
        } else {
            let ratingValue = Double(avgRating ?? "0") ?? 0

            HStack(spacing: 2) {
                ForEach(1...5, id: \.self) { star in
                    let diff = ratingValue - Double(star - 1)
                    Image(systemName: starIcon(for: diff))
                        .font(.system(size: 14))
                        .foregroundColor(diff > 0 ? .yellow : Color(UIColor.systemGray4))
                }
                Text(String(format: "%.1f", ratingValue))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.primaryText)
                    .padding(.leading, 4)
                Text("(\(reviewCount) review\(reviewCount == 1 ? "" : "s"))")
                    .font(Theme.Typography.caption2)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
    }

    private func starIcon(for diff: Double) -> String {
        if diff >= 0.75 { return "star.fill" }
        if diff >= 0.25 { return "star.leadinghalf.filled" }
        return "star"
    }
}

// MARK: - Inline Star Rating (compact, for cards)

struct InlineStarRating: View {
    let avgRating: String?
    let reviewCount: Int?

    var body: some View {
        let count = reviewCount ?? 0
        if count == 0 {
            EmptyView()
        } else {
            let ratingValue = Double(avgRating ?? "0") ?? 0
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.yellow)
                Text(String(format: "%.1f", ratingValue))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.primaryText)
                Text("(\(count))")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        }
    }
}

// MARK: - Skill Chip

struct SkillChip: View {
    let name: String
    let proficiency: String

    private var chipColor: Color {
        switch proficiency {
        case "expert": return Color(red: 0.85, green: 0.65, blue: 0.13) // gold
        case "intermediate": return Theme.Colors.accent
        default: return Color(UIColor.systemGray3)
        }
    }

    var body: some View {
        Text(name)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(chipColor)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(chipColor.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(chipColor.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Profile Completeness View

struct ProfileCompletenessView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var hasExperience = false
    @State private var hasAvailability = false
    @State private var hasResume = false
    @State private var showEditProfile = false
    @State private var showSkills = false
    @State private var showExperience = false
    @State private var showAvailability = false
    @State private var showResume = false

    private var workerDict: [String: AnyCodable]? {
        authStore.currentUser?.workerProfile?.value as? [String: AnyCodable]
    }

    private var completeness: (score: Int, missing: [(String, String, String)]) {
        var score = 0
        var missing: [(String, String, String)] = [] // (label, icon, destination)

        // Headline (10 pts)
        if let h = workerDict?["headline"]?.value as? String, !h.isEmpty {
            score += 10
        } else {
            missing.append(("Add a headline", "textformat", "editProfile"))
        }

        // Bio (20 pts)
        if let b = workerDict?["bio"]?.value as? String, !b.isEmpty {
            score += 20
        } else {
            missing.append(("Write a bio", "text.alignleft", "editProfile"))
        }

        // Skills (20 pts)
        if let skills = workerDict?["skills"]?.value as? [Any], !skills.isEmpty {
            score += 20
        } else {
            missing.append(("Add your skills", "sparkles", "skills"))
        }

        // Experience (20 pts)
        if hasExperience { score += 20 } else {
            missing.append(("Add work experience", "briefcase.fill", "experience"))
        }

        // Availability (10 pts)
        if hasAvailability { score += 10 } else {
            missing.append(("Set availability", "calendar", "availability"))
        }

        // Resume (10 pts)
        if hasResume { score += 10 } else {
            missing.append(("Upload your resume", "doc.fill", "resume"))
        }

        // Photo (10 pts)
        if authStore.currentUser?.profilePhoto?.isActive == true {
            score += 10
        } else {
            missing.append(("Add a profile photo", "camera.fill", "photo"))
        }

        return (score, missing)
    }

    var body: some View {
        let (score, missing) = completeness

        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Profile Completeness")
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color(UIColor.systemGray5), lineWidth: 4)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: Double(score) / 100.0)
                        .stroke(progressColor(score), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    Text("\(score)%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.Colors.primaryText)
                }
            }

            if !missing.isEmpty {
                VStack(spacing: 0) {
                    ForEach(missing, id: \.0) { item in
                        Button {
                            navigateTo(item.2)
                        } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: item.1)
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Colors.accent)
                                    .frame(width: 24)
                                Text(item.0)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.primaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.Colors.tertiaryText)
                            }
                            .padding(.vertical, Theme.Spacing.sm)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
        .task { await loadExtraData() }
        .navigationDestination(isPresented: $showEditProfile) { EditProfileView() }
        .navigationDestination(isPresented: $showSkills) { SkillsPickerView() }
        .navigationDestination(isPresented: $showExperience) { ExperienceListView() }
        .navigationDestination(isPresented: $showAvailability) { AvailabilityGridView() }
        .navigationDestination(isPresented: $showResume) { ResumeUploadView() }
    }

    private func progressColor(_ score: Int) -> Color {
        if score >= 80 { return Theme.Colors.accent }
        if score >= 50 { return Theme.Colors.secondaryText }
        return Theme.Colors.tertiaryText
    }

    private func navigateTo(_ destination: String) {
        switch destination {
        case "editProfile": showEditProfile = true
        case "skills": showSkills = true
        case "experience": showExperience = true
        case "availability": showAvailability = true
        case "resume": showResume = true
        default: break
        }
    }

    private func loadExtraData() async {
        // Check experience
        do {
            let resp: ExperienceListResponse = try await APIClient.shared.request(.myExperiences)
            hasExperience = !resp.experiences.isEmpty
        } catch { hasExperience = false }

        // Check availability
        do {
            let resp: AvailabilityResponse = try await APIClient.shared.request(.myAvailability)
            hasAvailability = !resp.slots.isEmpty
        } catch { hasAvailability = false }

        // Check resume
        do {
            let resp: ResumeStatusResponse = try await APIClient.shared.request(.resumeStatus)
            hasResume = resp.resume != nil
        } catch { hasResume = false }
    }
}

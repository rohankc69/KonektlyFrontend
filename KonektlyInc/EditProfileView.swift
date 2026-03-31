//
//  EditProfileView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-25.
//

import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var headline: String = ""
    @State private var bio: String = ""
    @State private var isSaving = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false
    @State private var showSkills = false
    @State private var showExperience = false
    @State private var showAvailability = false
    @State private var showResume = false

    private let headlineLimit = 120
    private let bioLimit = 1000

    private var workerProfileDict: [String: AnyCodable]? {
        authStore.currentUser?.workerProfile?.value as? [String: AnyCodable]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                // Headline
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Headline")
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.primaryText)

                    TextField("e.g. Experienced Barista | 5 Years", text: $headline)
                        .font(Theme.Typography.body)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                        .onChange(of: headline) { _, newValue in
                            if newValue.count > headlineLimit {
                                headline = String(newValue.prefix(headlineLimit))
                            }
                        }

                    Text("\(headline.count)/\(headlineLimit)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Bio
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Bio")
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.primaryText)

                    ZStack(alignment: .topLeading) {
                        if bio.isEmpty {
                            Text("Tell businesses about yourself...")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.tertiaryText)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.md + 4)
                        }

                        TextEditor(text: $bio)
                            .font(Theme.Typography.body)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .padding(Theme.Spacing.sm)
                            .background(Theme.Colors.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                            .onChange(of: bio) { _, newValue in
                                if newValue.count > bioLimit {
                                    bio = String(newValue.prefix(bioLimit))
                                }
                            }
                    }

                    Text("\(bio.count)/\(bioLimit)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(bio.count > bioLimit - 50 ? Theme.Colors.warning : Theme.Colors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Save button
                Button {
                    Task { await saveProfile() }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Save")
                        }
                    }
                    .primaryButtonStyle(isEnabled: !isSaving)
                }
                .disabled(isSaving)

                // Navigation sections
                VStack(spacing: 0) {
                    sectionHeader("Profile Details")

                    ProfileMenuItem(icon: "sparkles", title: "My Skills", subtitle: "Add your skills and expertise") {
                        showSkills = true
                    }
                    menuDivider

                    ProfileMenuItem(icon: "briefcase.fill", title: "Experience", subtitle: "Add your work history") {
                        showExperience = true
                    }
                    menuDivider

                    ProfileMenuItem(icon: "calendar", title: "Availability", subtitle: "Set your weekly schedule") {
                        showAvailability = true
                    }
                    menuDivider

                    ProfileMenuItem(icon: "doc.fill", title: "Resume", subtitle: "Upload your resume (PDF)") {
                        showResume = true
                    }
                }
                .background(Theme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.large))
            }
            .padding(Theme.Spacing.xl)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSkills) {
            SkillsPickerView()
        }
        .navigationDestination(isPresented: $showExperience) {
            ExperienceListView()
        }
        .navigationDestination(isPresented: $showAvailability) {
            AvailabilityGridView()
        }
        .navigationDestination(isPresented: $showResume) {
            ResumeUploadView()
        }
        .overlay(alignment: .top) {
            if showToast {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: toastIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(.white)
                    Text(toastMessage)
                        .font(Theme.Typography.caption)
                        .foregroundColor(.white)
                }
                .padding(Theme.Spacing.md)
                .background(toastIsError ? Theme.Colors.error : Theme.Colors.success)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { loadExisting() }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.Colors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.sm)
    }

    private var menuDivider: some View {
        Divider().padding(.leading, 68)
    }

    private func loadExisting() {
        if let dict = workerProfileDict {
            if let h = dict["headline"]?.value as? String { headline = h }
            if let b = dict["bio"]?.value as? String { bio = b }
        }
    }

    private func saveProfile() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let req = WorkerProfileUpdateRequest(headline: headline, bio: bio)
            let _: WorkerProfileUpdateResponse = try await APIClient.shared.request(.updateWorkerProfile(req))
            await authStore.loadCurrentUser()
            showSuccessToast("Profile updated!")
        } catch {
            showErrorToast(error.localizedDescription)
        }
    }

    private func showSuccessToast(_ msg: String) {
        toastMessage = msg
        toastIsError = false
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showToast = false }
        }
    }

    private func showErrorToast(_ msg: String) {
        toastMessage = msg
        toastIsError = true
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showToast = false }
        }
    }
}

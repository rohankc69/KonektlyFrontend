//
//  SkillsPickerView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-25.
//

import SwiftUI

struct SkillsPickerView: View {
    @State private var allSkills: [SkillDetail] = []
    @State private var selectedSkills: [Int: String] = [:]  // skill_id -> proficiency
    @State private var searchText = ""
    @State private var expandedCategories: Set<String> = []
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false
    @Environment(\.dismiss) private var dismiss

    private let maxSkills = 15
    private let proficiencyLevels = ["beginner", "intermediate", "expert"]

    private var groupedSkills: [(String, [SkillDetail])] {
        let filtered: [SkillDetail]
        if searchText.isEmpty {
            filtered = allSkills
        } else {
            let q = searchText.lowercased()
            filtered = allSkills.filter { $0.name.lowercased().contains(q) }
        }
        let grouped = Dictionary(grouping: filtered) { $0.category }
        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.Colors.tertiaryText)
                TextField("Search skills...", text: $searchText)
                    .font(Theme.Typography.body)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.tertiaryText)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)

            // Selection count
            HStack {
                Text("\(selectedSkills.count)/\(maxSkills) skills selected")
                    .font(Theme.Typography.caption)
                    .foregroundColor(selectedSkills.count >= maxSkills ? Theme.Colors.warning : Theme.Colors.secondaryText)
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.sm)

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedSkills, id: \.0) { category, skills in
                            categorySection(category: category, skills: skills)
                        }
                    }
                    .padding(.bottom, 80)
                }
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("My Skills")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await saveSkills() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                            .font(Theme.Typography.bodySemibold)
                            .foregroundColor(Theme.Colors.accent)
                    }
                }
                .disabled(isSaving)
            }
        }
        .overlay(alignment: .top) {
            if showToast {
                toastBanner
            }
        }
        .task { await loadData() }
    }

    @ViewBuilder
    private func categorySection(category: String, skills: [SkillDetail]) -> some View {
        let isExpanded = expandedCategories.contains(category)

        Button {
            withAnimation(Theme.Animation.quick) {
                if isExpanded {
                    expandedCategories.remove(category)
                } else {
                    expandedCategories.insert(category)
                }
            }
        } label: {
            HStack {
                Text(category)
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
                let count = skills.filter { selectedSkills[$0.id] != nil }.count
                if count > 0 {
                    Text("\(count)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.accent)
                        .clipShape(Capsule())
                }
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.Colors.secondaryText)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if isExpanded {
            ForEach(skills) { skill in
                skillRow(skill: skill)
                Divider().padding(.leading, 52)
            }
        }

        Divider()
    }

    @ViewBuilder
    private func skillRow(skill: SkillDetail) -> some View {
        let isSelected = selectedSkills[skill.id] != nil
        let isDisabled = !isSelected && selectedSkills.count >= maxSkills

        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Button {
                    if isSelected {
                        selectedSkills.removeValue(forKey: skill.id)
                    } else if !isDisabled {
                        selectedSkills[skill.id] = "intermediate"
                    }
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? Theme.Colors.accent : (isDisabled ? Theme.Colors.tertiaryText : Theme.Colors.secondaryText))
                }

                Text(skill.name)
                    .font(Theme.Typography.body)
                    .foregroundColor(isDisabled ? Theme.Colors.tertiaryText : Theme.Colors.primaryText)

                Spacer()
            }

            if isSelected {
                Picker("Proficiency", selection: Binding(
                    get: { selectedSkills[skill.id] ?? "intermediate" },
                    set: { selectedSkills[skill.id] = $0 }
                )) {
                    Text("Beginner").tag("beginner")
                    Text("Intermediate").tag("intermediate")
                    Text("Expert").tag("expert")
                }
                .pickerStyle(.segmented)
                .padding(.leading, 34)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var toastBanner: some View {
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

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let skillsReq: SkillsListResponse = APIClient.shared.request(.allSkills())
            async let myReq: WorkerSkillsResponse = APIClient.shared.request(.mySkills)

            let (allSkillsResp, mySkillsResp) = try await (skillsReq, myReq)
            allSkills = allSkillsResp.skills
            // Expand all categories by default
            expandedCategories = Set(allSkills.map { $0.category })

            for item in mySkillsResp.skills {
                selectedSkills[item.skill.id] = item.proficiency
            }
        } catch {
            print("[SKILLS] load error: \(error)")
        }
    }

    private func saveSkills() async {
        isSaving = true
        defer { isSaving = false }
        let idempotencyKey = UUID().uuidString

        let entries = selectedSkills.map { WorkerSkillEntry(skillId: $0.key, proficiency: $0.value) }
        let req = UpdateWorkerSkillsRequest(skills: entries)

        do {
            let _: WorkerSkillsResponse = try await APIClient.shared.request(.updateSkills(req, idempotencyKey: idempotencyKey))
            toastMessage = "Skills saved!"
            toastIsError = false
            withAnimation { showToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showToast = false }
            }
        } catch {
            toastMessage = error.localizedDescription
            toastIsError = true
            withAnimation { showToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation { showToast = false }
            }
        }
    }
}

//
//  ExperienceView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-25.
//

import SwiftUI

// MARK: - Experience List

struct ExperienceListView: View {
    @State private var experiences: [WorkExperience] = []
    @State private var isLoading = true
    @State private var showAddForm = false
    @State private var editingExperience: WorkExperience?
    @State private var showDeleteConfirm = false
    @State private var deleteTarget: WorkExperience?
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    private let maxExperiences = 20

    var body: some View {
        ZStack {
            if isLoading {
                ProgressView()
            } else if experiences.isEmpty {
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "briefcase")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Colors.tertiaryText)
                    Text("No experience added yet")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text("Add your work history to stand out")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                }
            } else {
                List {
                    ForEach(experiences) { exp in
                        experienceRow(exp)
                            .contentShape(Rectangle())
                            .onTapGesture { editingExperience = exp }
                    }
                    .onDelete { offsets in
                        if let idx = offsets.first {
                            deleteTarget = experiences[idx]
                            showDeleteConfirm = true
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("Experience")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if experiences.count < maxExperiences {
                    Button {
                        showAddForm = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(Theme.Colors.accent)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showAddForm) {
            ExperienceFormView { newExp in
                experiences.insert(newExp, at: 0)
                showAddForm = false
            }
        }
        .navigationDestination(item: $editingExperience) { exp in
            ExperienceFormView(existing: exp) { updated in
                if let idx = experiences.firstIndex(where: { $0.id == updated.id }) {
                    experiences[idx] = updated
                }
                editingExperience = nil
            }
        }
        .alert("Delete Experience", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let target = deleteTarget {
                    Task { await deleteExperience(target) }
                }
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("This experience entry will be permanently removed.")
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
        .task { await loadExperiences() }
    }

    @ViewBuilder
    private func experienceRow(_ exp: WorkExperience) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(exp.title)
                    .font(Theme.Typography.headlineSemibold)
                    .foregroundColor(Theme.Colors.primaryText)
                if exp.isCurrent {
                    Text("Current")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Theme.Colors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.accent.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            Text(exp.company)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
            Text(formatDateRange(start: exp.startDate, end: exp.endDate, isCurrent: exp.isCurrent))
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.tertiaryText)
            if let desc = exp.description, !desc.isEmpty {
                Text(desc)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }

    private func loadExperiences() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp: ExperienceListResponse = try await APIClient.shared.request(.myExperiences)
            experiences = resp.experiences
        } catch {
            print("[EXP] load error: \(error)")
        }
    }

    private func deleteExperience(_ exp: WorkExperience) async {
        do {
            let _: VoidAPIResponse = try await APIClient.shared.request(.deleteExperience(id: exp.id))
            experiences.removeAll { $0.id == exp.id }
            deleteTarget = nil
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

// MARK: - Experience Form

struct ExperienceFormView: View {
    let existing: WorkExperience?
    let onSave: (WorkExperience) -> Void

    @State private var title = ""
    @State private var company = ""
    @State private var descriptionText = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isCurrent = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(existing: WorkExperience? = nil, onSave: @escaping (WorkExperience) -> Void) {
        self.existing = existing
        self.onSave = onSave
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !company.trimmingCharacters(in: .whitespaces).isEmpty &&
        (isCurrent || endDate >= startDate)
    }

    var body: some View {
        Form {
            Section("Job Details") {
                TextField("Job Title *", text: $title)
                TextField("Company *", text: $company)
                ZStack(alignment: .topLeading) {
                    if descriptionText.isEmpty {
                        Text("Description (optional)")
                            .foregroundColor(Theme.Colors.tertiaryText)
                            .padding(.top, 8)
                    }
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                }
            }

            Section("Duration") {
                Toggle("I currently work here", isOn: $isCurrent)
                    .tint(Theme.Colors.accent)

                DatePicker("Start Date", selection: $startDate, displayedComponents: .date)

                if !isCurrent {
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.error)
                }
            }
        }
        .navigationTitle(existing != nil ? "Edit Experience" : "Add Experience")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                            .font(Theme.Typography.bodySemibold)
                            .foregroundColor(isValid ? Theme.Colors.accent : Theme.Colors.tertiaryText)
                    }
                }
                .disabled(!isValid || isSaving)
            }
        }
        .onAppear { loadExisting() }
    }

    private func loadExisting() {
        guard let exp = existing else { return }
        title = exp.title
        company = exp.company
        descriptionText = exp.description ?? ""
        isCurrent = exp.isCurrent
        if let d = dateFormatter.date(from: exp.startDate) { startDate = d }
        if let end = exp.endDate, let d = dateFormatter.date(from: end) { endDate = d }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        let idempotencyKey = UUID().uuidString

        let req = ExperienceRequest(
            title: title.trimmingCharacters(in: .whitespaces),
            company: company.trimmingCharacters(in: .whitespaces),
            description: descriptionText.isEmpty ? nil : descriptionText,
            startDate: dateFormatter.string(from: startDate),
            endDate: isCurrent ? nil : dateFormatter.string(from: endDate),
            isCurrent: isCurrent
        )

        do {
            if let existing {
                let resp: ExperienceResponse = try await APIClient.shared.request(.updateExperience(id: existing.id, req))
                onSave(resp.experience)
            } else {
                let resp: ExperienceResponse = try await APIClient.shared.request(.addExperience(req, idempotencyKey: idempotencyKey))
                onSave(resp.experience)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Helpers

private func formatDateRange(start: String, end: String?, isCurrent: Bool) -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    let displayFmt = DateFormatter()
    displayFmt.dateFormat = "MMM yyyy"

    let startStr: String
    if let d = fmt.date(from: start) {
        startStr = displayFmt.string(from: d)
    } else {
        startStr = start
    }

    if isCurrent { return "\(startStr) – Present" }

    if let end, let d = fmt.date(from: end) {
        return "\(startStr) – \(displayFmt.string(from: d))"
    }
    return startStr
}

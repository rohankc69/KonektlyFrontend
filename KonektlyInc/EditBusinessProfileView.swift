//
//  EditBusinessProfileView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-26.
//

import SwiftUI
import PhotosUI

struct EditBusinessProfileView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var companyBio: String = ""
    @State private var isSaving = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    // Logo upload
    @State private var showLogoPicker = false
    @State private var selectedLogoItem: PhotosPickerItem?
    @State private var logoPreviewImage: UIImage?
    @State private var isUploadingLogo = false
    @State private var showRemoveLogoConfirm = false

    private let bioLimit = 1000

    private var businessProfileDict: [String: AnyCodable]? {
        authStore.currentUser?.businessProfile?.value as? [String: AnyCodable]
    }

    private var businessName: String {
        businessProfileDict?["business_name"]?.value as? String ?? "Business"
    }

    private var existingLogoUrl: String? {
        businessProfileDict?["company_logo_url"]?.value as? String
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                // Logo section
                logoSection

                // Company Bio
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("About")
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.primaryText)

                    ZStack(alignment: .topLeading) {
                        if companyBio.isEmpty {
                            Text("Tell workers about your company...")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.tertiaryText)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.md + 4)
                        }

                        TextEditor(text: $companyBio)
                            .font(Theme.Typography.body)
                            .frame(minHeight: 120)
                            .scrollContentBackground(.hidden)
                            .padding(Theme.Spacing.sm)
                            .background(Theme.Colors.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                            .onChange(of: companyBio) { _, newValue in
                                if newValue.count > bioLimit {
                                    companyBio = String(newValue.prefix(bioLimit))
                                }
                            }
                    }

                    Text("\(companyBio.count)/\(bioLimit)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(companyBio.count > bioLimit - 50 ? Theme.Colors.warning : Theme.Colors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Save button
                Button {
                    Task { await saveBio() }
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
            }
            .padding(Theme.Spacing.xl)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Business Profile")
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(isPresented: $showLogoPicker, selection: $selectedLogoItem, matching: .images)
        .onChange(of: selectedLogoItem) { _, newItem in
            guard let newItem else { return }
            Task { await processLogoSelection(newItem) }
            selectedLogoItem = nil
        }
        .alert("Remove Logo", isPresented: $showRemoveLogoConfirm) {
            Button("Remove", role: .destructive) {
                Task { await removeLogo() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your company logo will be removed.")
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
                .background(toastIsError ? Theme.Colors.secondaryText : Theme.Colors.accent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear { loadExisting() }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Company Logo")
                .font(Theme.Typography.headlineSemibold)
                .foregroundColor(Theme.Colors.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Theme.Spacing.xl) {
                // Logo preview
                ZStack {
                    if let preview = logoPreviewImage {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    } else if let urlStr = existingLogoUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            logoPlaceholder
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    } else {
                        logoPlaceholder
                    }

                    if isUploadingLogo {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .fill(.black.opacity(0.4))
                            .frame(width: 80, height: 80)
                        ProgressView()
                            .tint(.white)
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Button {
                        showLogoPicker = true
                    } label: {
                        Text(existingLogoUrl != nil || logoPreviewImage != nil ? "Change Logo" : "Upload Logo")
                            .font(Theme.Typography.bodySemibold)
                            .foregroundColor(Theme.Colors.accent)
                    }
                    .disabled(isUploadingLogo)

                    if existingLogoUrl != nil || logoPreviewImage != nil {
                        Button {
                            showRemoveLogoConfirm = true
                        } label: {
                            Text("Remove")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.secondaryText)
                        }
                        .disabled(isUploadingLogo)
                    }

                    Text("JPEG or PNG, max 5 MB")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)
                }

                Spacer()
            }
        }
    }

    private var logoPlaceholder: some View {
        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
            .fill(Theme.Colors.inputBackground)
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "building.2.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Theme.Colors.tertiaryText)
            )
    }

    // MARK: - Data

    private func loadExisting() {
        if let dict = businessProfileDict {
            if let bio = dict["company_bio"]?.value as? String { companyBio = bio }
        }
    }

    private func saveBio() async {
        isSaving = true
        defer { isSaving = false }

        do {
            let req = BusinessProfileUpdateRequest(companyBio: companyBio)
            let _: BusinessProfileUpdateResponse = try await APIClient.shared.request(.updateBusinessProfile(req))
            await authStore.loadCurrentUser()
            showSuccessToast("Profile updated!")
        } catch {
            showErrorToast(error.localizedDescription)
        }
    }

    // MARK: - Logo Upload

    private func processLogoSelection(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            showErrorToast("Could not load the selected image.")
            return
        }

        guard let uiImage = UIImage(data: data) else {
            showErrorToast("The selected file is not a valid image.")
            return
        }

        guard let jpegData = uiImage.jpegData(compressionQuality: 0.85) else {
            showErrorToast("Could not process the image.")
            return
        }

        let maxSize = 5 * 1024 * 1024
        guard jpegData.count <= maxSize else {
            showErrorToast("Image is too large. Maximum size is 5 MB.")
            return
        }

        logoPreviewImage = uiImage
        await uploadLogo(data: jpegData, fileName: "logo.jpg", contentType: "image/jpeg")
    }

    private func uploadLogo(data: Data, fileName: String, contentType: String) async {
        isUploadingLogo = true
        defer { isUploadingLogo = false }

        do {
            // 1. Get presigned upload URL
            let urlReq = LogoUploadURLRequest(fileName: fileName, contentType: contentType, sizeBytes: data.count)
            let urlResp: LogoUploadURLResponse = try await APIClient.shared.request(.businessLogoUploadURL(urlReq))

            // 2. Upload raw file via PUT to presigned URL (spec: S3 PUT upload)
            if let s3Info = urlResp.upload {
                let uploadURL = s3Info.url
                let isLocal = uploadURL.hasPrefix("/")

                if isLocal {
                    _ = try await APIClient.shared.uploadLocal(
                        path: uploadURL,
                        photoId: 0,
                        fileData: data,
                        contentType: contentType,
                        fileName: fileName
                    )
                } else {
                    // Production: always PUT for business logo per backend spec
                    _ = try await APIClient.shared.uploadToS3Put(
                        url: uploadURL,
                        fileData: data,
                        contentType: contentType
                    )
                }
            } else if let uploadUrl = urlResp.uploadUrl {
                _ = try await APIClient.shared.uploadToS3Put(
                    url: uploadUrl, fileData: data, contentType: contentType
                )
            }

            // 3. Confirm with empty body per backend spec
            let _: LogoConfirmResponse = try await APIClient.shared.request(.businessLogoConfirm)

            await authStore.loadCurrentUser()
            showSuccessToast("Logo uploaded!")
        } catch {
            logoPreviewImage = nil
            showErrorToast(error.localizedDescription)
        }
    }

    private func removeLogo() async {
        isUploadingLogo = true
        defer { isUploadingLogo = false }

        do {
            let _: VoidAPIResponse = try await APIClient.shared.request(.deleteBusinessLogo)
            logoPreviewImage = nil
            await authStore.loadCurrentUser()
            showSuccessToast("Logo removed.")
        } catch {
            showErrorToast(error.localizedDescription)
        }
    }

    // MARK: - Toast

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

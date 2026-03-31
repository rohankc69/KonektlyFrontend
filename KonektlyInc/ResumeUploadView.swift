//
//  ResumeUploadView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ResumeUploadView: View {
    @State private var resumeInfo: ResumeInfo?
    @State private var isLoading = true
    @State private var isUploading = false
    @State private var uploadProgress: String?
    @State private var showFilePicker = false
    @State private var showDeleteConfirm = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsError = false

    private let maxSizeBytes = 5 * 1024 * 1024 // 5 MB
    private let uploadRetryAttempts = 3
    private let uploadRetryDelayNanoseconds: UInt64 = 800_000_000

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()

            if isLoading {
                ProgressView()
            } else if let resume = resumeInfo {
                // Has resume
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 56))
                        .foregroundColor(Theme.Colors.accent)

                    Text(resume.fileName ?? "Resume.pdf")
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.primaryText)

                    if let uploadedAt = resume.uploadedAt {
                        Text("Uploaded \(formatDate(uploadedAt))")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }

                    // Replace button
                    Button {
                        showFilePicker = true
                    } label: {
                        Text("Replace Resume")
                            .secondaryButtonStyle()
                    }
                    .padding(.horizontal, Theme.Spacing.xl)

                    // Remove button
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Text("Remove Resume")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
            } else {
                // No resume
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.system(size: 56))
                        .foregroundColor(Theme.Colors.tertiaryText)

                    Text("No resume uploaded")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)

                    Text("Upload a PDF (max 5 MB)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.tertiaryText)

                    Button {
                        showFilePicker = true
                    } label: {
                        Text("Upload Resume")
                            .primaryButtonStyle()
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }
            }

            if isUploading, let progress = uploadProgress {
                VStack(spacing: Theme.Spacing.sm) {
                    ProgressView()
                    Text(progress)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }

            Spacer()
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.background)
        .navigationTitle("Resume")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.pdf, UTType.data],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .alert("Remove Resume", isPresented: $showDeleteConfirm) {
            Button("Remove", role: .destructive) {
                Task { await deleteResume() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your resume will be permanently removed.")
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
        .task { await loadResume() }
    }

    private func loadResume() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp: ResumeStatusResponse = try await APIClient.shared.request(.resumeStatus)
            resumeInfo = resp.resume
        } catch let appError as AppError {
            resumeInfo = nil
            // Keep empty state for first-load experience, but surface real backend/network issues.
            switch appError {
            case .unauthorized:
                showError("Session expired. Please sign in again.")
            case .network:
                showError("Couldn't load resume. Check your connection and try again.")
            default:
                showError(appError.errorDescription ?? "Couldn't load resume.")
            }
        } catch {
            resumeInfo = nil
            showError("Couldn't load resume.")
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Validate it's a PDF by extension
            guard url.pathExtension.lowercased() == "pdf" else {
                showError("Please select a PDF file.")
                return
            }

            let didAccess = url.startAccessingSecurityScopedResource()

            // Copy the file to a temp location first — handles iCloud, external providers
            let data: Data
            let fileName: String
            do {
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)

                // Remove old temp file if exists
                try? FileManager.default.removeItem(at: tempURL)

                // Use coordinator for cross-process file access
                var coordError: NSError?
                var readData: Data?
                var readName: String?

                NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { coordURL in
                    readData = try? Data(contentsOf: coordURL)
                    readName = coordURL.lastPathComponent
                }

                if let coordError {
                    throw coordError
                }

                guard let fileData = readData else {
                    throw NSError(domain: "ResumeUpload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not read file data."])
                }

                data = fileData
                fileName = readName ?? url.lastPathComponent
            } catch {
                if didAccess { url.stopAccessingSecurityScopedResource() }
                showError("Could not read the selected file. Make sure it's downloaded.")
                return
            }

            if didAccess { url.stopAccessingSecurityScopedResource() }

            if data.count > maxSizeBytes {
                showError("File is too large. Maximum size is 5 MB.")
                return
            }

            Task { await uploadResume(data: data, fileName: fileName) }
        case .failure(let error):
            showError(error.localizedDescription)
        }
    }

    private func uploadResume(data: Data, fileName: String) async {
        isUploading = true
        uploadProgress = "Getting upload URL..."
        let idempotencyKey = UUID().uuidString
        defer {
            isUploading = false
            uploadProgress = nil
        }

        do {
            // Step 1: Get upload URL
            let urlReq = ResumeUploadURLRequest(fileName: fileName, contentType: "application/pdf", sizeBytes: data.count)
            let urlResp: ResumeUploadURLResponse = try await APIClient.shared.request(.resumeUploadURL(urlReq, idempotencyKey: idempotencyKey))

            // Step 2: Upload to storage (retry applies to this step only)
            uploadProgress = "Uploading..."
            try await uploadResumeToStorageWithRetry(response: urlResp, data: data, fileName: fileName)

            // Step 3: Confirm
            uploadProgress = "Confirming..."
            let _: ResumeConfirmResponse = try await APIClient.shared.request(.resumeConfirm)

            resumeInfo = ResumeInfo(id: urlResp.resumeId, fileName: fileName, uploadedAt: nil)
            showSuccess("Resume uploaded!")
        } catch let appError as AppError {
            if case .network(let underlying) = appError,
               let urlError = underlying as? URLError {
                switch urlError.code {
                case .timedOut:
                    showError("Upload timed out. Please try again on a stable connection.")
                case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                    showError("Upload host is unreachable. Please try again in a moment.")
                case .notConnectedToInternet:
                    showError("No internet connection. Please check your network and try again.")
                default:
                    showError("Network error during upload. Please try again.")
                }
            } else if case .conflict(let message) = appError {
                showError(message.isEmpty ? "Upload conflict (409). Please try again." : message)
            } else if case .rateLimited(_) = appError {
                showError(appError.errorDescription ?? "Too many requests (429). Please wait and try again.")
            } else {
                showError(appError.errorDescription ?? "Resume upload failed.")
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func uploadResumeToStorageWithRetry(response: ResumeUploadURLResponse, data: Data, fileName: String) async throws {
        for attempt in 1...uploadRetryAttempts {
            do {
                try await uploadResumeToStorage(response: response, data: data, fileName: fileName)
                return
            } catch let appError as AppError {
                let isLastAttempt = attempt == uploadRetryAttempts
                guard shouldRetryUpload(error: appError), !isLastAttempt else {
                    throw appError
                }
                try? await Task.sleep(nanoseconds: uploadRetryDelayNanoseconds * UInt64(attempt))
            }
        }
        throw AppError.apiError(code: .uploadFailed, message: "Upload failed after retries.")
    }

    private func uploadResumeToStorage(response: ResumeUploadURLResponse, data: Data, fileName: String) async throws {
        // Resume spec: S3 PUT upload (raw body, Content-Type: application/pdf)
        if let upload = response.upload {
            let uploadMethod = upload.method.uppercased()
            if uploadMethod == "POST" && !upload.fields.isEmpty {
                _ = try await APIClient.shared.uploadToS3(
                    url: upload.url,
                    fields: upload.fields,
                    fileData: data,
                    contentType: "application/pdf",
                    fileName: fileName,
                    orderedFields: upload.orderedFields
                )
            } else {
                _ = try await APIClient.shared.uploadToS3Put(
                    url: upload.url,
                    fileData: data,
                    contentType: "application/pdf"
                )
            }
            return
        }

        if let uploadUrl = response.uploadUrl, !uploadUrl.isEmpty {
            _ = try await APIClient.shared.uploadToS3Put(
                url: uploadUrl,
                fileData: data,
                contentType: "application/pdf"
            )
            return
        }

        throw AppError.apiError(code: .uploadFailed, message: "Invalid upload response format.")
    }

    private func shouldRetryUpload(error: AppError) -> Bool {
        if case .network(let underlying) = error,
           let urlError = underlying as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
        return false
    }

    private func deleteResume() async {
        do {
            let _: VoidAPIResponse = try await APIClient.shared.request(.resumeDelete)
            resumeInfo = nil
            showSuccess("Resume removed.")
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func showSuccess(_ msg: String) {
        toastMessage = msg
        toastIsError = false
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showToast = false }
        }
    }

    private func showError(_ msg: String) {
        toastMessage = msg
        toastIsError = true
        withAnimation { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showToast = false }
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

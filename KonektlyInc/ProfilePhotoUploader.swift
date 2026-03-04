//
//  ProfilePhotoUploader.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-03.
//

import Foundation
import Combine
import PhotosUI
import SwiftUI
import CryptoKit

// MARK: - Upload State

nonisolated enum PhotoUploadState: Equatable, Sendable {
    case idle
    case selecting
    case validating
    case uploading(progress: Double)
    case confirming
    case processing(photoId: Int, elapsed: TimeInterval)
    case success(ProfilePhoto)
    case error(String)

    static func == (lhs: PhotoUploadState, rhs: PhotoUploadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.selecting, .selecting): return true
        case (.validating, .validating): return true
        case (.uploading(let a), .uploading(let b)): return a == b
        case (.confirming, .confirming): return true
        case (.processing(let a, _), .processing(let b, _)): return a == b
        case (.success(let a), .success(let b)): return a.id == b.id
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Uploader

@MainActor
final class ProfilePhotoUploader: ObservableObject {

    @Published var state: PhotoUploadState = .idle
    @Published var previewImage: UIImage?

    // Constraints
    private let maxFileSize: Int = 5 * 1024 * 1024 // 5 MB
    private let allowedTypes: Set<String> = ["image/jpeg", "image/png", "image/webp"]
    private let maxPollingDuration: TimeInterval = 30
    private let pollingInterval: TimeInterval = 2

    private var pollingTask: Task<Void, Never>?

    var isActive: Bool {
        switch state {
        case .idle, .success, .error: return false
        default: return true
        }
    }

    // MARK: - Process Selected Photo

    func processSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        state = .selecting

        // Load image data from PhotosPicker
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            state = .error("Could not load the selected image.")
            return
        }

        guard let uiImage = UIImage(data: data) else {
            state = .error("The selected file is not a valid image.")
            return
        }

        state = .validating
        previewImage = uiImage

        // Determine content type
        let contentType = detectContentType(data: data)
        guard allowedTypes.contains(contentType) else {
            state = .error("Unsupported format. Please use JPEG, PNG, or WebP.")
            return
        }

        // Re-encode as JPEG for consistent upload (controls size)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.85) else {
            state = .error("Could not process the image.")
            return
        }

        guard jpegData.count <= maxFileSize else {
            state = .error("Image is too large. Maximum size is 5 MB.")
            return
        }

        // Compute SHA-256
        let hash = SHA256.hash(data: jpegData)
        let sha256 = hash.compactMap { String(format: "%02x", $0) }.joined()

        await upload(imageData: jpegData, contentType: "image/jpeg", sha256: sha256)
    }

    // MARK: - Upload Flow

    private func upload(imageData: Data, contentType: String, sha256: String) async {
        state = .uploading(progress: 0.1)

        do {
            // 1. Get presigned upload URL from backend
            let req = PhotoUploadURLRequest(
                fileName: "avatar.jpg",
                contentType: contentType,
                sizeBytes: imageData.count,
                sha256: sha256
            )

            state = .uploading(progress: 0.2)

            let uploadInfo: PhotoUploadURLResponse = try await APIClient.shared.request(
                .photoUploadURL(req)
            )

            state = .uploading(progress: 0.4)

            // 2. Upload file - detect local vs S3 mode
            let uploadURL = uploadInfo.upload.url
            let isLocalUpload = uploadURL.hasPrefix("/")

            if isLocalUpload {
                // Dev mode: upload to backend directly with Bearer auth
                _ = try await APIClient.shared.uploadLocal(
                    path: uploadURL,
                    photoId: uploadInfo.photoId,
                    fileData: imageData,
                    contentType: contentType,
                    fileName: "avatar.jpg"
                )
            } else {
                // Production: upload to S3 with presigned fields
                _ = try await APIClient.shared.uploadToS3(
                    url: uploadURL,
                    fields: uploadInfo.upload.fields,
                    fileData: imageData,
                    contentType: contentType,
                    fileName: "avatar.jpg"
                )
            }

            state = .uploading(progress: 0.8)

            // 3. Confirm upload with backend - check HTTP status
            state = .confirming
            let confirmReq = PhotoConfirmRequest(photoId: uploadInfo.photoId)
            let (confirmResp, httpStatus): (PhotoConfirmResponse, Int) =
                try await APIClient.shared.requestWithStatus(.photoConfirm(confirmReq))

            // 4. 200 = active, 202 = processing (poll)
            if httpStatus == 202 || confirmResp.profilePhoto.isProcessing {
                await pollUntilActive(photoId: confirmResp.profilePhoto.id)
            } else {
                state = .success(confirmResp.profilePhoto)
                if let user = confirmResp.user {
                    AuthStore.shared.updateUser(user)
                }
            }

        } catch let appError as AppError {
            state = .error(appError.errorDescription ?? "Upload failed. Please try again.")
        } catch {
            state = .error("Upload failed. Please try again.")
        }
    }

    // MARK: - Poll for Processing

    private func pollUntilActive(photoId: Int) async {
        pollingTask?.cancel()
        let start = Date()

        state = .processing(photoId: photoId, elapsed: 0)

        pollingTask = Task {
            while !Task.isCancelled {
                let elapsed = Date().timeIntervalSince(start)
                guard elapsed < maxPollingDuration else {
                    state = .error("Photo processing timed out. Please try again later.")
                    return
                }

                state = .processing(photoId: photoId, elapsed: elapsed)

                try? await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))

                // Fetch latest user
                await AuthStore.shared.loadCurrentUser()
                if let photo = AuthStore.shared.currentUser?.profilePhoto, photo.isActive {
                    state = .success(photo)
                    return
                }
            }
        }
    }

    // MARK: - Delete Photo

    func deletePhoto() async {
        state = .uploading(progress: 0.5)
        do {
            let _: EmptyDataResponse = try await APIClient.shared.request(.photoDelete)
            previewImage = nil
            state = .idle
            await AuthStore.shared.loadCurrentUser()
        } catch let appError as AppError {
            state = .error(appError.errorDescription ?? "Could not delete photo.")
        } catch {
            state = .error("Could not delete photo.")
        }
    }

    // MARK: - Reset

    func reset() {
        pollingTask?.cancel()
        pollingTask = nil
        state = .idle
        previewImage = nil
    }

    // MARK: - Helpers

    private func detectContentType(data: Data) -> String {
        guard data.count >= 4 else { return "application/octet-stream" }
        var header = [UInt8](repeating: 0, count: 4)
        data.copyBytes(to: &header, count: 4)

        // JPEG: FF D8 FF
        if header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF {
            return "image/jpeg"
        }
        // PNG: 89 50 4E 47
        if header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47 {
            return "image/png"
        }
        // WebP: RIFF....WEBP
        if header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46 {
            return "image/webp"
        }
        return "application/octet-stream"
    }
}

// MARK: - Empty response for delete

nonisolated struct EmptyDataResponse: Decodable, Sendable {}

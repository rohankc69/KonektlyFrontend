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
    private let allowedTypes: Set<String> = ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"]
    private let maxPollingDuration: TimeInterval = 90
    private let pollingInterval: TimeInterval = 3

    private var pollingTask: Task<Void, Never>?

    var isActive: Bool {
        switch state {
        case .idle, .success, .error: return false
        default: return true
        }
    }

    // MARK: - Process Selected Photo (direct from PhotosPickerItem)

    func processSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        state = .selecting

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            state = .error("Could not load the selected image.")
            return
        }

        guard let uiImage = UIImage(data: data) else {
            state = .error("The selected file is not a valid image.")
            return
        }

        await uploadFromConfirmedImage(image: uiImage, originalData: data)
    }

    // MARK: - Upload from Confirmed Image (after preview confirmation)

    func uploadFromConfirmedImage(image: UIImage, originalData: Data) async {
        state = .validating
        previewImage = image

        let contentType = detectContentType(data: originalData)
        guard allowedTypes.contains(contentType) else {
            state = .error("Unsupported format. Please use JPEG, PNG, WebP, HEIC, or HEIF.")
            return
        }

        guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
            state = .error("Could not process the image.")
            return
        }

        guard jpegData.count <= maxFileSize else {
            state = .error("Image is too large. Maximum size is 5 MB.")
            return
        }

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

            // 2. Upload file — respect backend-provided method
            let uploadURL = uploadInfo.upload.url
            let isLocalUpload = uploadURL.hasPrefix("/")
            let uploadMethod = uploadInfo.upload.method.uppercased()
            print("[PHOTO] Upload target: method=\(uploadMethod), local=\(isLocalUpload), fields=\(uploadInfo.upload.fields.keys.sorted()), url=\(uploadURL.prefix(60))")

            if isLocalUpload {
                // Dev mode: upload to backend directly with Bearer auth
                _ = try await APIClient.shared.uploadLocal(
                    path: uploadURL,
                    photoId: uploadInfo.photoId,
                    fileData: imageData,
                    contentType: contentType,
                    fileName: "avatar.jpg"
                )
            } else if uploadMethod == "POST" && !uploadInfo.upload.fields.isEmpty {
                // Presigned S3 POST (multipart/form-data with returned fields)
                _ = try await APIClient.shared.uploadToS3(
                    url: uploadURL,
                    fields: uploadInfo.upload.fields,
                    fileData: imageData,
                    contentType: contentType,
                    fileName: "avatar.jpg",
                    orderedFields: uploadInfo.upload.orderedFields
                )
            } else {
                // Presigned S3 PUT (raw body upload) — default for production
                _ = try await APIClient.shared.uploadToS3Put(
                    url: uploadURL,
                    fileData: imageData,
                    contentType: contentType
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
                // Keep previewImage so avatar shows immediately
                // Backend URL will be used on next app launch when previewImage is nil
            }

        } catch let appError as AppError {
            if case .network(let underlying) = appError,
               let urlError = underlying as? URLError {
                switch urlError.code {
                case .timedOut:
                    state = .error("Upload timed out. Please try again on a stable connection.")
                case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                    state = .error("Upload host is unreachable. Please try again in a moment.")
                case .notConnectedToInternet:
                    state = .error("No internet connection. Please check your network and try again.")
                default:
                    state = .error("Network error during upload. Please try again.")
                }
            } else {
                state = .error(appError.errorDescription ?? "Upload failed. Please try again.")
            }
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
                    state = .error("Photo is still processing — it may appear shortly. Restart the app if it doesn't show.")
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
        var header4 = [UInt8](repeating: 0, count: 4)
        data.copyBytes(to: &header4, count: 4)

        // JPEG: FF D8 FF
        if header4[0] == 0xFF && header4[1] == 0xD8 && header4[2] == 0xFF {
            return "image/jpeg"
        }
        // PNG: 89 50 4E 47
        if header4[0] == 0x89 && header4[1] == 0x50 && header4[2] == 0x4E && header4[3] == 0x47 {
            return "image/png"
        }
        // WebP: RIFF....WEBP
        if header4[0] == 0x52 && header4[1] == 0x49 && header4[2] == 0x46 && header4[3] == 0x46 {
            return "image/webp"
        }
        // HEIC/HEIF: ISO BMFF brand in ftyp box at bytes [4...11]
        if data.count >= 12 {
            var header12 = [UInt8](repeating: 0, count: 12)
            data.copyBytes(to: &header12, count: 12)
            if header12[4] == 0x66 && header12[5] == 0x74 && header12[6] == 0x79 && header12[7] == 0x70 {
                let brand = String(bytes: Array(header12[8...11]), encoding: .ascii) ?? ""
                let heicBrands: Set<String> = ["heic", "heix", "hevc", "hevx"]
                let heifBrands: Set<String> = ["mif1", "msf1"]
                if heicBrands.contains(brand) { return "image/heic" }
                if heifBrands.contains(brand) { return "image/heif" }
            }
        }
        return "application/octet-stream"
    }
}

// MARK: - Empty response for delete

nonisolated struct EmptyDataResponse: Decodable, Sendable {}

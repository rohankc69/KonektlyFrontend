//
//  ReviewPromptView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-25.
//

import SwiftUI

// MARK: - Review Prompt (Bottom Sheet)

struct ReviewPromptView: View {
    let jobId: Int
    let otherUserName: String
    let otherUserPhotoUrl: String?
    let jobTitle: String
    let onDismiss: () -> Void

    @State private var rating: Int = 0
    @State private var comment: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @StateObject private var reviewStore = ReviewStore.shared

    private let commentLimit = 500

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xxl) {
                // Header
                VStack(spacing: Theme.Spacing.md) {
                    // Other user photo
                    AvatarImageView(
                        previewImage: nil,
                        photoURL: otherUserPhotoUrl.flatMap { URL(string: $0) },
                        isUploading: false,
                        size: 64
                    )

                    Text(otherUserName)
                        .font(Theme.Typography.title3)
                        .foregroundColor(Theme.Colors.primaryText)

                    Text(jobTitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }

                // Star rating
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            withAnimation(Theme.Animation.quick) {
                                rating = star
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 36))
                                .foregroundColor(star <= rating ? .yellow : Color(UIColor.systemGray4))
                        }
                    }
                }

                // Comment
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ZStack(alignment: .topLeading) {
                        if comment.isEmpty {
                            Text("How was your experience? (optional)")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.tertiaryText)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.md + 4)
                        }
                        TextEditor(text: $comment)
                            .font(Theme.Typography.body)
                            .frame(minHeight: 80)
                            .scrollContentBackground(.hidden)
                            .padding(Theme.Spacing.sm)
                            .background(Theme.Colors.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                            .onChange(of: comment) { _, newValue in
                                if newValue.count > commentLimit {
                                    comment = String(newValue.prefix(commentLimit))
                                }
                            }
                    }
                    Text("\(comment.count)/\(commentLimit)")
                        .font(Theme.Typography.caption2)
                        .foregroundColor(Theme.Colors.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.error)
                }

                Spacer()

                // Submit
                Button {
                    Task { await submitReview() }
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Submit Review")
                        }
                    }
                    .primaryButtonStyle(isEnabled: rating > 0 && !isSubmitting)
                }
                .disabled(rating == 0 || isSubmitting)

                // Maybe Later
                Button {
                    onDismiss()
                } label: {
                    Text("Maybe Later")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .padding(.bottom, Theme.Spacing.lg)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.xl)
            .navigationTitle("Leave a Review")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
    }

    private var successOverlay: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(Theme.Colors.success)
            Text("Thanks for your review!")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.primaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background.opacity(0.95))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onDismiss()
            }
        }
    }

    private func submitReview() async {
        isSubmitting = true
        defer { isSubmitting = false }
        errorMessage = nil
        let idempotencyKey = UUID().uuidString

        do {
            _ = try await reviewStore.submitReview(
                jobId: jobId,
                rating: rating,
                comment: comment.isEmpty ? nil : comment,
                idempotencyKey: idempotencyKey
            )
            withAnimation { showSuccess = true }
        } catch let error as AppError {
            switch error {
            case .apiError(let code, _):
                switch code {
                case .alreadyReviewed:
                    errorMessage = "You've already reviewed this job."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { onDismiss() }
                case .reviewWindowExpired:
                    errorMessage = "The review period for this job has expired."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { onDismiss() }
                default:
                    errorMessage = error.localizedDescription
                }
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

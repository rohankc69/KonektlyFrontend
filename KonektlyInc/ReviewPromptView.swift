//
//  ReviewPromptView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-03-25.
//

import SwiftUI

// MARK: - Review prompt sheet

/// Who the current user is rating (copy only; same API for both roles).
enum ReviewPromptRole: Sendable {
    case rateWorker
    case rateBusiness

    var contextHeadline: String {
        switch self {
        case .rateWorker: return "Rate your worker"
        case .rateBusiness: return "Rate this business"
        }
    }

    var primaryPrompt: String {
        switch self {
        case .rateWorker: return "How was their work?"
        case .rateBusiness: return "How was your shift with this employer?"
        }
    }
}

struct ReviewPromptView: View {
    let jobId: Int
    let role: ReviewPromptRole
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

    private var ratingVerb: String? {
        switch rating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Very good"
        case 5: return "Excellent"
        default: return nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                VStack(spacing: Theme.Spacing.sm) {
                    Text(role.primaryPrompt)
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.primaryText)
                        .multilineTextAlignment(.center)
                        .padding(.top, Theme.Spacing.md)

                    Text(role.contextHeadline)
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.tertiaryText)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                .padding(.horizontal, Theme.Spacing.lg)

                VStack(spacing: Theme.Spacing.md) {
                    AvatarImageView(
                        previewImage: nil,
                        photoURL: otherUserPhotoUrl.flatMap { URL(string: $0) },
                        isUploading: false,
                        size: Theme.Sizes.avatarLarge
                    )
                    .overlay(
                        Circle()
                            .stroke(Theme.Colors.border.opacity(0.4), lineWidth: 1)
                    )

                    Text(otherUserName)
                        .font(Theme.Typography.title3)
                        .foregroundColor(Theme.Colors.primaryText)

                    Text(jobTitle)
                        .font(Theme.Typography.subheadline)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                HStack(spacing: Theme.Spacing.lg) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            withAnimation(Theme.Animation.smooth) {
                                rating = star
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.system(size: 40))
                                .foregroundColor(star <= rating ? Theme.Colors.ratingStarActive : Theme.Colors.ratingStarInactive)
                        }
                        .buttonStyle(.plain)
                        .frame(minWidth: Theme.Sizes.minTouchTarget, minHeight: Theme.Sizes.minTouchTarget)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Rate \(star) out of 5")
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)

                if let ratingVerb, rating > 0 {
                    Text(ratingVerb)
                        .font(Theme.Typography.subheadline.weight(.semibold))
                        .foregroundColor(Theme.Colors.accent)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Add a note (optional)")
                        .font(Theme.Typography.caption.weight(.medium))
                        .foregroundColor(Theme.Colors.secondaryText)

                    ZStack(alignment: .topLeading) {
                        if comment.isEmpty {
                            Text("Share more detail to help others…")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.tertiaryText)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.md + 2)
                        }
                        TextEditor(text: $comment)
                            .font(Theme.Typography.body)
                            .frame(minHeight: 72)
                            .scrollContentBackground(.hidden)
                            .padding(Theme.Spacing.sm)
                            .background(Theme.Colors.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
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
                .padding(.horizontal, Theme.Spacing.xs)

                if let errorMessage {
                    Text(errorMessage)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(spacing: Theme.Spacing.md) {
                    Button {
                        Task { await submitReview() }
                    } label: {
                        ZStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(rating > 0 ? "Submit" : "Select a rating")
                            }
                        }
                        .primaryButtonStyle(isEnabled: rating > 0 && !isSubmitting)
                    }
                    .disabled(rating == 0 || isSubmitting)

                    Button {
                        onDismiss()
                    } label: {
                        Text("Maybe later")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.accent)
                    }
                }
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.CornerRadius.large)
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
            Text("Thanks for your feedback!")
                .font(Theme.Typography.title3)
                .foregroundColor(Theme.Colors.primaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.overlayBackground)
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
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

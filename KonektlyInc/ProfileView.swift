//
//  ProfileView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var authStore: AuthStore
    @AppStorage("userRole") private var userRoleRaw: String = UserRole.worker.rawValue
    @State private var showSettings = false
    @State private var showTerms = false
    @State private var showSubscription = false
    @State private var showEditProfile = false
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @StateObject private var photoUploader = ProfilePhotoUploader()
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    private var userRole: UserRole {
        UserRole(rawValue: userRoleRaw) ?? .worker
    }

    private var currentUser: AuthUser? { authStore.currentUser }

    private var displayName: String {
        let first = currentUser?.firstName ?? ""
        let last = currentUser?.lastName ?? ""
        let full = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        return full.isEmpty ? "Your Name" : full
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {

                // MARK: Profile Header
                VStack(spacing: Theme.Spacing.lg) {

                    // Avatar with photo picker
                    ZStack(alignment: .bottomTrailing) {
                        avatarView
                            .frame(width: Theme.Sizes.avatarExtraLarge, height: Theme.Sizes.avatarExtraLarge)

                        if subscriptionManager.isKonektlyPlus {
                            ActiveSubscriptionBadge()
                                .offset(x: -Theme.Sizes.avatarExtraLarge / 4, y: 0)
                        }

                        // Camera button — triggers photo picker
                        PhotosPicker(
                            selection: $selectedPhoto,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.Colors.accent)
                                .background(Circle().fill(Color(UIColor.systemBackground)).padding(-4))
                        }
                        .offset(x: -2, y: -2)
                        .onChange(of: selectedPhoto) { _, item in
                            guard let item else { return }
                            Task { await photoUploader.processSelectedPhoto(item) }
                            selectedPhoto = nil
                        }
                    }
                    .padding(.top, Theme.Spacing.lg)

                    // Upload progress overlay
                    if photoUploader.isActive {
                        photoUploadStatusView
                    }

                    // Name and role
                    VStack(spacing: Theme.Spacing.xs) {
                        Text(displayName)
                            .font(Theme.Typography.title1)
                            .foregroundColor(Theme.Colors.primaryText)

                        Text(userRole == .worker ? "Worker" : "Business Owner")
                            .font(Theme.Typography.subheadline)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)

                // MARK: Subscription card
                if subscriptionManager.isKonektlyPlus {
                    ActiveSubscriptionCard { showSubscription = true }
                        .padding(.horizontal, Theme.Spacing.lg)
                } else {
                    UpgradeCard { showSubscription = true }
                        .padding(.horizontal, Theme.Spacing.lg)
                }

                // MARK: Settings list
                VStack(spacing: 0) {
                    SettingsRow(icon: "person.fill", title: "Edit Profile", showChevron: true) {
                        showEditProfile = true
                    }
                    Divider().padding(.leading, 52)

                    SettingsRow(
                        icon: "star.circle.fill",
                        title: subscriptionManager.isKonektlyPlus ? "Konektly+ Active" : "Upgrade to Konektly+",
                        showChevron: true
                    ) {
                        showSubscription = true
                    }
                    Divider().padding(.leading, 52)

                    SettingsRow(icon: "gearshape.fill", title: "Settings", showChevron: true) {
                        showSettings = true
                    }
                    Divider().padding(.leading, 52)

                    SettingsRow(icon: "doc.text.fill", title: "Terms & Conditions", showChevron: true) {
                        showTerms = true
                    }
                }
                .cardStyle()
                .padding(.horizontal, Theme.Spacing.lg)

                // MARK: Logout
                Button(action: logout) {
                    Text("Log Out")
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Sizes.buttonHeight)
                        .background(Theme.Colors.cardBackground)
                        .cornerRadius(Theme.CornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
                        )
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(Theme.Colors.primaryText)
                }
            }
        }
        .navigationDestination(isPresented: $showTerms) {
            TermsReadView()
        }
        .navigationDestination(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showSubscription) {
            NavigationStack {
                SubscriptionView()
                    .navigationTitle("Konektly+")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { showSubscription = false }
                        }
                    }
            }
        }
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarView: some View {
        if let preview = photoUploader.previewImage {
            Image(uiImage: preview)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
        } else if let url = currentUser?.profilePhoto?.displayURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill().clipShape(Circle())
                case .failure:
                    defaultAvatar
                case .empty:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    defaultAvatar
                }
            }
        } else {
            defaultAvatar
        }
    }

    private var defaultAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Theme.Colors.buttonPrimary, Theme.Colors.buttonPrimary.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            )
    }

    // MARK: - Upload status

    @ViewBuilder
    private var photoUploadStatusView: some View {
        switch photoUploader.state {
        case .uploading(let progress):
            HStack(spacing: Theme.Spacing.sm) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 120)
                Text("Uploading…")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }
        case .confirming:
            Label("Saving…", systemImage: "arrow.clockwise")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        case .processing:
            Label("Processing…", systemImage: "hourglass")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        case .error(let msg):
            Label(msg, systemImage: "exclamationmark.circle")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.error)
        default:
            EmptyView()
        }
    }

    // MARK: - Logout

    private func logout() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        Task { await APIClient.shared.logout() }
        authStore.signOut()
    }
}

// MARK: - Stat View

struct StatView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: Theme.Sizes.iconLarge))
                .foregroundColor(color)
            Text(value)
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.primaryText)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.secondaryText)
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String
    let showChevron: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: Theme.Sizes.iconMedium))
                    .foregroundColor(Theme.Colors.primaryText)
                    .frame(width: 28)
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.primaryText)
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: Theme.Sizes.iconSmall))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            .padding(Theme.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y),
                proposal: .unspecified
            )
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineH: CGFloat = 0
            for subview in subviews {
                let s = subview.sizeThatFits(.unspecified)
                if x + s.width > maxWidth && x > 0 { x = 0; y += lineH + spacing; lineH = 0 }
                positions.append(CGPoint(x: x, y: y))
                lineH = max(lineH, s.height)
                x += s.width + spacing
            }
            size = CGSize(width: maxWidth, height: y + lineH)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(AuthStore.shared)
    }
}

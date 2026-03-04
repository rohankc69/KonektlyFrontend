//
//  VerificationStatusView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI
import PhotosUI

struct VerificationStatusView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var photoUploader = ProfilePhotoUploader()
    @State private var isRefreshing = false
    @State private var showEmailVerification = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showDeleteConfirm = false

    private var user: AuthUser? { authStore.currentUser }
    private var status: ProfileStatus? { authStore.profileStatus }

    private var displayName: String {
        if let first = user?.firstName, let last = user?.lastName,
           !first.isEmpty, !last.isEmpty {
            return "\(first) \(last)"
        }
        return user?.phone ?? "Account"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header: Name + Avatar
                    headerSection
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.top, Theme.Spacing.xl)
                        .padding(.bottom, Theme.Spacing.xxl)

                    // Quick action cards
                    quickActions
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.bottom, Theme.Spacing.xxl)

                    // Menu list
                    menuList
                        .padding(.bottom, Theme.Spacing.xxl)
                }
            }
            .background(Theme.Colors.background)
            .refreshable { await refresh() }
            .overlay(alignment: .top) {
                // Photo upload error/success banner
                if case .error(let msg) = photoUploader.state {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(msg)
                            .font(Theme.Typography.caption)
                            .foregroundColor(.white)
                        Spacer()
                        Button { photoUploader.reset() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.error)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: photoUploader.state)
                }
            }
            .sheet(isPresented: $showEmailVerification) {
                NavigationStack {
                    EmailVerificationView()
                        .environmentObject(authStore)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") { showEmailVerification = false }
                            }
                        }
                }
            }
        }
        .task { await refresh() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(displayName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Theme.Colors.primaryText)
            }

            Spacer()

            // Avatar - clickable to upload
            avatarView
        }
    }

    // MARK: - Avatar

    private var avatarView: some View {
        let previewImg = photoUploader.previewImage
        let isUploading = photoUploader.isActive
        let photoURL = user?.profilePhoto?.displayURL
        let hasPhoto = user?.profilePhoto != nil

        return PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            AvatarImageView(
                previewImage: previewImg,
                photoURL: photoURL,
                isUploading: isUploading
            )
        }
        .disabled(isUploading)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await photoUploader.processSelectedPhoto(newItem)
                selectedPhotoItem = nil
            }
        }
        .contextMenu {
            if hasPhoto {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Remove Photo", systemImage: "trash")
                }
            }
        }
        .alert("Remove Photo", isPresented: $showDeleteConfirm) {
            Button("Remove", role: .destructive) {
                Task { await photoUploader.deletePhoto() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your profile photo will be removed.")
        }
        .accessibilityLabel("Profile photo. Tap to change.")
        .accessibilityHint("Opens photo picker to upload a new profile photo")
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: Theme.Spacing.md) {
            QuickActionCard(icon: "briefcase.fill", label: "Shifts") {}
            QuickActionCard(icon: "wallet.bifold.fill", label: "Wallet") {}
            QuickActionCard(icon: "doc.text.fill", label: "History") {}
        }
    }

    // MARK: - Menu List

    private var menuList: some View {
        VStack(spacing: 0) {
            // Verification section
            if let status = status {
                let role = authStore.selectedRole
                let profileStatus = role == .worker ? status.workerStatus : status.businessStatus
                if let profileStatus, profileStatus.lowercased() != "approved" {
                    ProfileMenuItem(
                        icon: "shield.lefthalf.filled",
                        title: "Verification Status",
                        subtitle: statusSubtitle(profileStatus),
                        statusColor: profileStatusColor(profileStatus)
                    ) {}
                    menuDivider
                }
            }

            // Email verification
            ProfileMenuItem(
                icon: "envelope.fill",
                title: "Email",
                subtitle: emailSubtitle
            ) {
                if user?.emailVerified != true {
                    showEmailVerification = true
                }
            }
            menuDivider

            // Profile type
            ProfileMenuItem(
                icon: authStore.selectedRole == .worker ? "person.fill" : "building.2.fill",
                title: authStore.selectedRole == .worker ? "Worker Profile" : "Business Profile",
                subtitle: "Manage your profile details"
            ) {}
            menuDivider

            ProfileMenuItem(
                icon: "bell.fill",
                title: "Notifications",
                subtitle: "Manage your alerts"
            ) {}
            menuDivider

            ProfileMenuItem(
                icon: "questionmark.circle.fill",
                title: "Help",
                subtitle: nil
            ) {}
            menuDivider

            ProfileMenuItem(
                icon: "lock.fill",
                title: "Privacy",
                subtitle: nil
            ) {}
            menuDivider

            ProfileMenuItem(
                icon: "gearshape.fill",
                title: "Settings",
                subtitle: nil
            ) {}
            menuDivider

            // Sign out
            Button(action: { authStore.signOut() }) {
                HStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Colors.error)
                        .frame(width: 28)

                    Text("Sign Out")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.error)

                    Spacer()
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.lg)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var menuDivider: some View {
        Divider()
            .padding(.leading, 68)
    }

    // MARK: - Helpers

    private var emailSubtitle: String {
        if let email = user?.email, !email.isEmpty {
            return user?.emailVerified == true ? email : "\(email) (unverified)"
        }
        return "Add email for account recovery"
    }

    private func statusSubtitle(_ status: String) -> String {
        switch status.lowercased() {
        case "pending": return "Under review"
        case "rejected": return "Needs attention"
        case "approved": return "Verified"
        default: return status.capitalized
        }
    }

    private func profileStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "approved": return Theme.Colors.success
        case "rejected": return Theme.Colors.error
        case "pending": return .orange
        default: return .gray
        }
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await authStore.loadProfileStatus()
        await authStore.loadCurrentUser()
    }
}

// MARK: - Avatar Image View

struct AvatarImageView: View {
    let previewImage: UIImage?
    let photoURL: URL?
    let isUploading: Bool

    var body: some View {
        ZStack {
            if let preview = previewImage {
                Image(uiImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
            } else if let photoURL {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    case .failure:
                        placeholderCircle
                    default:
                        ProgressView()
                            .frame(width: 60, height: 60)
                    }
                }
            } else {
                placeholderCircle
            }

            if isUploading {
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 60, height: 60)
                ProgressView()
                    .tint(.white)
            }

            if !isUploading {
                Image(systemName: "camera.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black)
                    .clipShape(Circle())
                    .offset(x: 22, y: 22)
            }
        }
    }

    private var placeholderCircle: some View {
        ZStack {
            Circle()
                .fill(Color(UIColor.systemGray5))
                .frame(width: 60, height: 60)
            Image(systemName: "person.fill")
                .font(.system(size: 28))
                .foregroundColor(Color(UIColor.systemGray2))
        }
    }
}

// MARK: - Quick Action Card

struct QuickActionCard: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(Theme.Colors.primaryText)
                Text(label)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.lg)
            .background(Color(UIColor.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Menu Item

struct ProfileMenuItem: View {
    let icon: String
    let title: String
    let subtitle: String?
    var statusColor: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Theme.Colors.primaryText)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }

                Spacer()

                if let color = statusColor {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(UIColor.systemGray3))
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VerificationStatusView()
        .environmentObject(AuthStore.shared)
}

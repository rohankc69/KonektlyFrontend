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
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isRefreshing = false
    @State private var showEmailVerification = false
    @State private var emailVerificationSheetID = UUID()
    @State private var showSubscription = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showDeleteConfirm = false
    @State private var showPhotoOptions = false
    @State private var showPhotoPicker = false
    @State private var showPhotoPreview = false
    @State private var pendingImage: UIImage?
    @State private var pendingImageData: Data?
    @State private var showTerms = false
    @State private var showPrivacy = false
    @State private var showBlockedUsers = false
    @State private var showNotificationPrefs = false
    @State private var showDeleteAccount = false
    @State private var showDataExport = false
    @State private var showSignOutConfirm = false
    @State private var showEditProfile = false
    @State private var showEditBusinessProfile = false
    @State private var showHistory = false
    @State private var showSupport = false
    @State private var showReviewPrompt = false
    @State private var reviewJob: PendingReviewJob?
    @StateObject private var reviewStore = ReviewStore.shared

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

                    // Profile completeness (workers only)
                    if authStore.selectedRole == .worker {
                        ProfileCompletenessView()
                            .environmentObject(authStore)
                            .padding(.horizontal, Theme.Spacing.xl)
                            .padding(.bottom, Theme.Spacing.xxl)
                    }

                    // Menu list
                    menuList
                        .padding(.bottom, Theme.Spacing.xxl)
                }
            }
            .background(Theme.Colors.background)
            .refreshable { await refresh() }
            .navigationDestination(isPresented: $showTerms) {
                TermsReadView()
            }
            .navigationDestination(isPresented: $showPrivacy) {
                PrivacyReadView()
            }
            .navigationDestination(isPresented: $showBlockedUsers) {
                BlockedUsersView()
            }
            .navigationDestination(isPresented: $showNotificationPrefs) {
                NotificationPreferencesView()
            }
            .navigationDestination(isPresented: $showDeleteAccount) {
                DeleteAccountView()
            }
            .navigationDestination(isPresented: $showDataExport) {
                DataExportView()
            }
            .navigationDestination(isPresented: $showEditProfile) {
                EditProfileView()
            }
            .navigationDestination(isPresented: $showEditBusinessProfile) {
                EditBusinessProfileView()
                    .environmentObject(authStore)
            }
            .navigationDestination(isPresented: $showHistory) {
                HistoryView()
            }
            .navigationDestination(isPresented: $showSupport) {
                SupportView()
            }
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
                        .id(emailVerificationSheetID)
                        .environmentObject(authStore)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") { showEmailVerification = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showReviewPrompt) {
                if let job = reviewJob {
                    ReviewPromptView(
                        jobId: job.id,
                        role: .rateBusiness,
                        otherUserName: job.otherUserName,
                        otherUserPhotoUrl: job.otherUserPhotoUrl,
                        jobTitle: job.title,
                        onDismiss: { showReviewPrompt = false; reviewJob = nil }
                    )
                }
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
            .alert(item: Binding(
                get: { subscriptionManager.restoreResultAlert },
                set: { subscriptionManager.restoreResultAlert = $0 }
            )) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .task { await refresh() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Avatar on top - clickable to upload
            avatarView

            // Name below avatar
            Text(displayName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Theme.Colors.primaryText)

            // Phone number subtitle
            if let phone = user?.phone, !phone.isEmpty,
               displayName != phone {
                Text(phone)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.secondaryText)
            }

            // Rating (from worker_profile or business_profile)
            if authStore.selectedRole == .worker,
               let dict = user?.workerProfile?.value as? [String: AnyCodable] {
                let avgRating = dict["avg_rating"]?.value as? String
                let reviewCount = dict["review_count"]?.value as? Int ?? 0
                StarRatingView(avgRating: avgRating, reviewCount: reviewCount)
            } else if authStore.selectedRole == .business,
                      let dict = user?.businessProfile?.value as? [String: AnyCodable] {
                let avgRating = dict["avg_rating"]?.value as? String
                let reviewCount = dict["review_count"]?.value as? Int ?? 0
                StarRatingView(avgRating: avgRating, reviewCount: reviewCount)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Avatar

    private var avatarView: some View {
        let previewImg = photoUploader.previewImage
        let isUploading = photoUploader.isActive
        let photoURL = user?.profilePhoto?.displayURL
        let hasPhoto = user?.profilePhoto != nil

        return Button {
            if !isUploading {
                showPhotoOptions = true
            }
        } label: {
            AvatarImageView(
                previewImage: previewImg,
                photoURL: photoURL,
                isUploading: isUploading,
                size: 80
            )
        }
        .disabled(isUploading)
        .confirmationDialog("Profile Photo", isPresented: $showPhotoOptions, titleVisibility: .visible) {
            Button("Choose Photo") {
                showPhotoPicker = true
            }
            if hasPhoto {
                Button("Remove Photo", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                // Load the image for preview, don't upload yet
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    pendingImage = image
                    pendingImageData = data
                    showPhotoPreview = true
                }
                selectedPhotoItem = nil
            }
        }
        .sheet(isPresented: $showPhotoPreview) {
            photoPreviewSheet
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
        .accessibilityHint("Opens options to change or remove your profile photo")
    }

    // MARK: - Photo Preview Sheet

    private var photoPreviewSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                if let image = pendingImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(Circle())
                        .frame(width: 240, height: 240)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                }

                Spacer()

                // Use This Photo button
                Button {
                    showPhotoPreview = false
                    if let data = pendingImageData, let image = pendingImage {
                        Task {
                            await photoUploader.uploadFromConfirmedImage(image: image, originalData: data)
                            pendingImage = nil
                            pendingImageData = nil
                        }
                    }
                } label: {
                    Text("Use This Photo")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.Colors.buttonPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.md)

                // Choose Different button
                Button {
                    showPhotoPreview = false
                    pendingImage = nil
                    pendingImageData = nil
                    // Reopen picker after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showPhotoPicker = true
                    }
                } label: {
                    Text("Choose Different")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(Theme.Colors.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.lg)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showPhotoPreview = false
                        pendingImage = nil
                        pendingImageData = nil
                    }
                    .foregroundColor(Theme.Colors.primaryText)
                }
            }
        }
    }

    // MARK: - Menu List

    private var menuList: some View {
        VStack(spacing: 0) {
            // ── Account ──

            sectionHeader("Account")

            // Profile
            ProfileMenuItem(
                icon: authStore.selectedRole == .worker ? "person.fill" : "building.2.fill",
                title: authStore.selectedRole == .worker ? "Edit Profile" : "Business Profile",
                subtitle: authStore.selectedRole == .worker ? "Headline, bio, skills & more" : "Company bio, logo & details"
            ) {
                if authStore.selectedRole == .worker {
                    showEditProfile = true
                } else {
                    showEditBusinessProfile = true
                }
            }
            menuDivider

            // Verification (only if not approved)
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

            // Email (always tappable: add, verify, or change — replacement happens after verifying the new address)
            ProfileMenuItem(
                icon: "envelope.fill",
                title: "Email",
                subtitle: emailSubtitle
            ) {
                emailVerificationSheetID = UUID()
                showEmailVerification = true
            }
            menuDivider

            // Konektly+ subscription
            SubscriptionMenuItem(isActive: subscriptionManager.isKonektlyPlus) {
                showSubscription = true
            }
            menuDivider
            ProfileMenuItem(
                icon: "arrow.clockwise.circle",
                title: "Restore Purchases",
                subtitle: "Sync Konektly+ from the App Store"
            ) {
                Task { await subscriptionManager.restorePurchases() }
            }

            // ── Activity ──

            sectionHeader("Activity")

            ProfileMenuItem(
                icon: "clock.arrow.circlepath",
                title: "History",
                subtitle: "View your shift history"
            ) {
                showHistory = true
            }

            // ── Notifications ──

            sectionHeader("Notifications")

            ProfileMenuItem(
                icon: "bell.fill",
                title: "Notifications",
                subtitle: "Manage your alerts"
            ) {
                showNotificationPrefs = true
            }

            // ── Legal ──

            sectionHeader("Legal")

            ProfileMenuItem(
                icon: "doc.text.fill",
                title: "Terms & Conditions",
                subtitle: nil
            ) {
                showTerms = true
            }
            menuDivider

            ProfileMenuItem(
                icon: "hand.raised.fill",
                title: "Privacy Policy",
                subtitle: nil
            ) {
                showPrivacy = true
            }

            // ── Privacy & Data ──

            sectionHeader("Privacy & Data")

            ProfileMenuItem(
                icon: "square.and.arrow.down",
                title: "Export My Data",
                subtitle: "Download a copy of your data"
            ) {
                showDataExport = true
            }
            menuDivider

            ProfileMenuItem(
                icon: "trash",
                title: "Delete Account",
                subtitle: "Permanently delete your account"
            ) {
                showDeleteAccount = true
            }

            // ── Support ──

            sectionHeader("Support")

            ProfileMenuItem(
                icon: "questionmark.circle.fill",
                title: "Help & Support",
                subtitle: "FAQs and ticket support"
            ) {
                showSupport = true
            }
            menuDivider

            ProfileMenuItem(
                icon: "hand.raised.fill",
                title: "Blocked Users",
                subtitle: nil
            ) {
                showBlockedUsers = true
            }

            // ── Sign Out ──

            menuDivider

            ProfileMenuItem(
                icon: "rectangle.portrait.and.arrow.right",
                title: "Sign Out",
                subtitle: nil
            ) {
                showSignOutConfirm = true
            }
            .alert("Sign Out", isPresented: $showSignOutConfirm) {
                Button("Sign Out", role: .destructive) {
                    authStore.signOut()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(Theme.Colors.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.sm)
    }

    private var menuDivider: some View {
        Divider()
            .padding(.leading, 68)
    }

    // MARK: - Helpers

    private var emailSubtitle: String {
        if let email = user?.email, !email.isEmpty {
            if user?.emailVerified == true {
                return "\(email) · Tap to change"
            }
            return "\(email) (unverified)"
        }
        return "Add or change email for account recovery"
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
        await reviewStore.loadPendingReviews()
        // Only clear preview if backend says no photo exists (deleted/none)
        if authStore.currentUser?.profilePhoto == nil {
            photoUploader.previewImage = nil
        }
        // Debug: log what photo URL we have
        if let photo = authStore.currentUser?.profilePhoto {
            print("[AVATAR] profilePhoto: id=\(photo.id) status=\(photo.status) url256=\(photo.url256 ?? "nil") version=\(photo.version ?? "nil")")
            print("[AVATAR] resolved displayURL: \(photo.displayURL?.absoluteString ?? "nil")")
        } else {
            print("[AVATAR] profilePhoto is nil")
        }
    }
}

// MARK: - Avatar Image View

struct AvatarImageView: View {
    let previewImage: UIImage?
    let photoURL: URL?
    let isUploading: Bool
    var size: CGFloat = 60

    @State private var loadedImage: UIImage?
    @State private var loadFailed = false
    @State private var lastLoadedURL: URL?

    private var badgeOffset: CGFloat { size * 0.37 }
    private var badgeSize: CGFloat { max(10, size * 0.17) }

    var body: some View {
        ZStack {
            if let preview = previewImage {
                Image(uiImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let loaded = loadedImage {
                Image(uiImage: loaded)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if photoURL != nil && !loadFailed {
                ProgressView()
                    .frame(width: size, height: size)
            } else {
                placeholderCircle
            }

            if isUploading {
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: size, height: size)
                ProgressView()
                    .tint(.white)
            }

            if !isUploading {
                Image(systemName: "camera.fill")
                    .font(.system(size: badgeSize, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.black)
                    .clipShape(Circle())
                    .offset(x: badgeOffset, y: badgeOffset)
            }
        }
        .task(id: photoURL) {
            await loadImageFromURL()
        }
        .onChange(of: photoURL) { _, newURL in
            if newURL != nil && loadedImage == nil {
                Task { await loadImageFromURL() }
            }
        }
        .onAppear {
            print("[AVATAR VIEW] appeared: previewImage=\(previewImage != nil) photoURL=\(photoURL?.absoluteString ?? "nil") loadedImage=\(loadedImage != nil)")
        }
    }

    private func loadImageFromURL() async {
        guard let url = photoURL else {
            loadedImage = nil
            loadFailed = false
            return
        }

        // Skip if already loaded this URL
        if url == lastLoadedURL && loadedImage != nil { return }

        loadFailed = false
        loadedImage = nil

        do {
            var request = URLRequest(url: url)
            // Add auth header only for backend-hosted media URLs.
            // Do not send JWT to third-party hosts (e.g. S3/CDN presigned URLs).
            if url.host == Config.apiBaseURL.host, let token = TokenStore.shared.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            request.cachePolicy = .reloadIgnoringLocalCacheData

            print("[AVATAR] Loading image from: \(url.absoluteString)")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("[AVATAR] Image load response: HTTP \(httpResponse.statusCode), \(data.count) bytes")
            }

            if let image = UIImage(data: data) {
                loadedImage = image
                lastLoadedURL = url
                print("[AVATAR] Image loaded successfully (\(data.count) bytes)")
            } else {
                // If the response is XML or HTML, it's likely an S3 error (e.g. 403 SignatureMismatch)
                let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
                print("[AVATAR] Failed to decode image — response body: \(preview)")
                loadFailed = true
            }
        } catch {
            print("[AVATAR] Image load error: \(error.localizedDescription)")
            loadFailed = true
        }
    }

    private var placeholderCircle: some View {
        ZStack {
            Circle()
                .fill(Color(UIColor.systemGray5))
                .frame(width: size, height: size)
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.47))
                .foregroundColor(Color(UIColor.systemGray2))
        }
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

// MARK: - Subscription Menu Item

struct SubscriptionMenuItem: View {
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.lg) {
                Image(systemName: isActive ? "checkmark.seal.fill" : "star.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.Colors.accent)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isActive ? "Konektly+" : "Upgrade to Konektly+")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.primaryText)
                    Text(isActive ? "All premium features active" : "Unlock exact locations & more")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }

                Spacer()

                if isActive {
                    Text("Active")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Colors.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.success.opacity(0.12))
                        .clipShape(Capsule())
                } else {
                    Text("Upgrade")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.accent)
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(UIColor.systemGray3))
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

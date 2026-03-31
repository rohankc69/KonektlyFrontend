//
//  BlockedUsersView.swift
//  KonektlyInc
//
//  Shows blocked users with the ability to unblock them.
//

import SwiftUI

struct BlockedUsersView: View {
    @EnvironmentObject private var messageStore: MessageStore
    @State private var blockedUsers: [BlockedUser] = []
    @State private var isLoading = true
    @State private var unblockingId: Int?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if blockedUsers.isEmpty {
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "hand.raised.slash")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Colors.tertiaryText)

                    Text("No blocked users")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(blockedUsers) { user in
                        HStack {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.tertiaryBackground)
                                    .frame(width: 40, height: 40)

                                Text(initials(for: user))
                                    .font(Theme.Typography.body.weight(.semibold))
                                    .foregroundColor(Theme.Colors.primaryText)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName.isEmpty ? "User" : user.displayName)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.primaryText)

                                Text("Blocked \(timeAgo(user.blockedAt))")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.secondaryText)
                            }

                            Spacer()

                            Button {
                                unblock(user)
                            } label: {
                                if unblockingId == user.id {
                                    ProgressView()
                                        .frame(width: 70)
                                } else {
                                    Text("Unblock")
                                        .font(Theme.Typography.caption.weight(.semibold))
                                        .foregroundColor(Theme.Colors.accent)
                                        .padding(.horizontal, Theme.Spacing.md)
                                        .padding(.vertical, Theme.Spacing.xs)
                                        .background(Theme.Colors.accent.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                            .disabled(unblockingId != nil)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadBlockedUsers()
        }
        .overlay(alignment: .bottom) {
            if let error = errorMessage {
                Text(error)
                    .font(Theme.Typography.caption)
                    .foregroundColor(.white)
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.error)
                    .cornerRadius(Theme.CornerRadius.small)
                    .padding(Theme.Spacing.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { errorMessage = nil }
                        }
                    }
            }
        }
    }

    private func loadBlockedUsers() async {
        isLoading = true
        defer { isLoading = false }
        do {
            blockedUsers = try await messageStore.loadBlockedUsers()
        } catch {
            print("[BLOCK] Failed to load blocked users: \(error)")
            errorMessage = "Failed to load blocked users"
        }
    }

    private func unblock(_ user: BlockedUser) {
        unblockingId = user.id
        Task {
            do {
                try await messageStore.unblockUser(userId: user.userId)
                withAnimation {
                    blockedUsers.removeAll { $0.id == user.id }
                }
                // Refresh conversations since unblocked user's chats reappear
                await messageStore.loadConversations()
            } catch {
                print("[BLOCK] Unblock failed: \(error)")
                withAnimation { errorMessage = "Failed to unblock user" }
            }
            unblockingId = nil
        }
    }

    private func initials(for user: BlockedUser) -> String {
        let first = user.firstName?.prefix(1) ?? ""
        let last = user.lastName?.prefix(1) ?? ""
        let result = "\(first)\(last)".uppercased()
        return result.isEmpty ? "?" : result
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

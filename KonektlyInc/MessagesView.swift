//
//  MessagesView.swift
//  KonektlyInc
//
//  Created by Rohan on 2026-02-23.
//

import SwiftUI

struct MessagesView: View {
    @State private var searchText = ""
    
    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return MockData.conversations
        }
        return MockData.conversations.filter {
            $0.otherUser.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.Colors.secondaryText)
                        .font(.system(size: Theme.Sizes.iconMedium))
                    
                    TextField("Search messages...", text: $searchText)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.Colors.secondaryText)
                                .font(.system(size: Theme.Sizes.iconMedium))
                        }
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.tertiaryBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .padding(Theme.Spacing.lg)
                
                // Conversations list
                if filteredConversations.isEmpty {
                    EmptyStateView(
                        icon: "bubble.left.and.bubble.right",
                        title: "No messages",
                        subtitle: searchText.isEmpty ? "Start a conversation with a business or worker" : "No results found"
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredConversations) { conversation in
                                NavigationLink {
                                    ChatView(conversation: conversation)
                                } label: {
                                    ConversationRow(conversation: conversation)
                                }
                                .buttonStyle(.plain)
                                
                                Divider()
                                    .padding(.leading, Theme.Sizes.avatarMedium + Theme.Spacing.lg * 2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            // Avatar
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Theme.Colors.tertiaryBackground)
                    .frame(width: Theme.Sizes.avatarMedium, height: Theme.Sizes.avatarMedium)
                
                Image(systemName: conversation.otherUser.avatarName)
                    .font(.system(size: 24))
                    .foregroundColor(Theme.Colors.primaryText)
                
                // Online indicator
                Circle()
                    .fill(Theme.Colors.success)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color(UIColor.systemBackground), lineWidth: 2)
                    )
                    .offset(x: 2, y: 2)
            }
            
            // Content
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text(conversation.otherUser.name)
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.primaryText)
                    
                    if conversation.otherUser.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: Theme.Sizes.iconSmall))
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    Text(timeAgoString(from: conversation.lastMessage.timestamp))
                        .font(Theme.Typography.caption)
                        .foregroundColor(conversation.unreadCount > 0 ? Theme.Colors.accent : Theme.Colors.secondaryText)
                }
                
                HStack {
                    Text(conversation.lastMessage.text)
                        .font(Theme.Typography.body)
                        .foregroundColor(conversation.unreadCount > 0 ? Theme.Colors.primaryText : Theme.Colors.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(Theme.Typography.caption.weight(.bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .padding(.horizontal, Theme.Spacing.xs)
                            .background(Theme.Colors.accent)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(conversation.unreadCount > 0 ? Theme.Colors.tertiaryBackground.opacity(0.3) : Color.clear)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return "\(day)d"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m"
        } else {
            return "now"
        }
    }
}

// MARK: - Chat View

struct ChatView: View {
    let conversation: Conversation
    @State private var messageText = ""
    @State private var messages: [Message] = []
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.md) {
                    ForEach(messages) { message in
                        MessageBubble(
                            message: message,
                            isFromCurrentUser: message.senderId == MockData.currentUser.id
                        )
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            
            Divider()
            
            // Input bar
            HStack(spacing: Theme.Spacing.md) {
                // Attachment button
                Button(action: {}) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Theme.Colors.primary)
                }
                
                // Text field
                HStack(spacing: Theme.Spacing.sm) {
                    TextField("Type a message...", text: $messageText)
                        .font(Theme.Typography.body)
                        .focused($isInputFocused)
                    
                    if !messageText.isEmpty {
                        Button(action: { messageText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.Colors.tertiaryText)
                        }
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.tertiaryBackground)
                .cornerRadius(Theme.CornerRadius.pill)
                
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: messageText.isEmpty ? "arrow.up.circle" : "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(messageText.isEmpty ? Theme.Colors.tertiaryText : Theme.Colors.accent)
                }
                .disabled(messageText.isEmpty)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.background)
        }
        .navigationTitle(conversation.otherUser.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: Theme.Spacing.md) {
                    Button(action: {}) {
                        Image(systemName: "phone.fill")
                            .foregroundColor(Theme.Colors.primary)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "info.circle")
                            .foregroundColor(Theme.Colors.primary)
                    }
                }
            }
        }
        .onAppear {
            messages = MockData.sampleMessages(for: conversation.id)
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newMessage = Message(
            senderId: MockData.currentUser.id,
            senderName: MockData.currentUser.name,
            text: messageText,
            timestamp: Date(),
            isRead: true
        )
        
        withAnimation(Theme.Animation.quick) {
            messages.append(newMessage)
        }
        
        messageText = ""
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: Theme.Spacing.xs) {
                Text(message.text)
                    .font(Theme.Typography.body)
                    .foregroundColor(isFromCurrentUser ? .white : Theme.Colors.primary)
                    .padding(Theme.Spacing.md)
                    .background(isFromCurrentUser ? Theme.Colors.primary : Theme.Colors.tertiaryBackground)
                    .cornerRadius(Theme.CornerRadius.large)
                
                Text(formatTimestamp(message.timestamp))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.tertiaryText)
            
            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Typography.title3)
                    .foregroundColor(Theme.Colors.primary)
                
                Text(subtitle)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.tertiaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xxxl)
    }
}

#Preview {
    NavigationStack {
        MessagesView()
    }
}

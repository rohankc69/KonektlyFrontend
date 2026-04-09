//
//  SupportView.swift
//  KonektlyInc
//

import SwiftUI

// MARK: - Support Hub

struct SupportView: View {
    @StateObject private var store = SupportStore.shared
    @State private var selectedTab = 0
    @State private var faqSearch = ""
    @State private var showNewTicket = false
    @State private var selectedTicketNumber: String?
    @State private var showTicketDetail = false

    private var filteredFAQs: [SupportFAQ] {
        faqSearch.isEmpty ? store.faqs
        : store.faqs.filter {
            $0.question.localizedCaseInsensitiveContains(faqSearch)
                || $0.answer.localizedCaseInsensitiveContains(faqSearch)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SupportWebsiteLinkCard()
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)
            Picker("", selection: $selectedTab) {
                Text("FAQ").tag(0)
                Text("My Tickets").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(Theme.Spacing.lg)

            if selectedTab == 0 {
                faqTab
            } else {
                ticketsTab
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if selectedTab == 1 {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewTicket = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.Colors.primaryText)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showTicketDetail) {
            if let num = selectedTicketNumber {
                SupportTicketDetailView(ticketNumber: num)
            }
        }
        .sheet(isPresented: $showNewTicket, onDismiss: { store.clearCreateError() }) {
            NavigationStack {
                NewTicketView { _ in
                    showNewTicket = false
                    selectedTab = 1
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            store.clearCreateError()
                            showNewTicket = false
                        }
                        .foregroundColor(Theme.Colors.primaryText)
                    }
                }
            }
        }
        .task {
            await store.fetchFAQs()
            await store.fetchTickets()
        }
    }

    // MARK: - FAQ Tab

    @ViewBuilder
    private var faqTab: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                // Search bar
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.Colors.secondaryText)
                    TextField("Search help articles...", text: $faqSearch)
                        .font(Theme.Typography.body)
                        .autocorrectionDisabled()
                    if !faqSearch.isEmpty {
                        Button { faqSearch = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.Colors.tertiaryText)
                        }
                    }
                }
                .padding(Theme.Spacing.md)
                .background(Theme.Colors.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                .padding(.horizontal, Theme.Spacing.lg)

                if store.isLoadingFAQs {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.xl)
                } else if filteredFAQs.isEmpty {
                    emptySupportView(
                        icon: "questionmark.bubble",
                        title: faqSearch.isEmpty ? "No FAQs yet" : "No results",
                        subtitle: faqSearch.isEmpty
                            ? "Check back soon for help articles."
                            : "Try a different search term."
                    )
                } else {
                    ForEach(filteredFAQs) { faq in
                        FAQExpandableRow(faq: faq) { isHelpful in
                            Task { await store.voteFAQ(id: faq.id, isHelpful: isHelpful) }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                    }
                }
            }
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xxl)
        }
    }

    // MARK: - Tickets Tab

    @ViewBuilder
    private var ticketsTab: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                if store.isLoadingTickets {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Spacing.xl)
                } else if let err = store.ticketsError {
                    errorView(err.errorDescription ?? "Something went wrong.")
                } else if store.tickets.isEmpty {
                    emptySupportView(
                        icon: "ticket",
                        title: "No tickets yet",
                        subtitle: "Tap + to open a new support request."
                    )
                } else {
                    ForEach(store.tickets) { ticket in
                        TicketRowView(ticket: ticket) {
                            selectedTicketNumber = ticket.ticketNumber
                            showTicketDetail = true
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                    }
                }
            }
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.xxl)
        }
    }

    // MARK: - Shared empty / error helpers

    private func emptySupportView(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(Theme.Colors.tertiaryText)
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.primaryText)
            Text(subtitle)
                .font(Theme.Typography.subheadline)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.top, Theme.Spacing.huge)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 36))
                .foregroundColor(Theme.Colors.tertiaryText)
            Text(message)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
            Button("Try Again") { Task { await store.fetchTickets() } }
                .font(Theme.Typography.subheadline.weight(.semibold))
                .foregroundColor(Theme.Colors.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.top, Theme.Spacing.huge)
    }
}

// MARK: - FAQ Expandable Row

private struct FAQExpandableRow: View {
    let faq: SupportFAQ
    let onVote: (Bool) -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Question header — toggles expansion
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.Colors.accent)
                        .frame(width: 24)
                        .padding(.top, 1)
                    Text(faq.question)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.primaryText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.Colors.tertiaryText)
                }
                .padding(Theme.Spacing.lg)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Divider()
                        .padding(.horizontal, Theme.Spacing.lg)

                    Text(faq.answer)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.secondaryText)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .fixedSize(horizontal: false, vertical: true)

                    // Helpful voting
                    HStack(spacing: Theme.Spacing.md) {
                        Text("Was this helpful?")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                        Spacer()
                        // Helpful
                        Button { onVote(true) } label: {
                            HStack(spacing: 4) {
                                Image(systemName: faq.userVote == "helpful"
                                      ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    .font(.system(size: 15))
                                if faq.helpfulCount > 0 {
                                    Text("\(faq.helpfulCount)")
                                        .font(Theme.Typography.caption)
                                }
                            }
                            .foregroundColor(faq.userVote == "helpful"
                                             ? Theme.Colors.success : Theme.Colors.secondaryText)
                        }
                        .buttonStyle(.plain)
                        // Not Helpful
                        Button { onVote(false) } label: {
                            HStack(spacing: 4) {
                                Image(systemName: faq.userVote == "not_helpful"
                                      ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                                    .font(.system(size: 15))
                                if faq.notHelpfulCount > 0 {
                                    Text("\(faq.notHelpfulCount)")
                                        .font(Theme.Typography.caption)
                                }
                            }
                            .foregroundColor(faq.userVote == "not_helpful"
                                             ? Theme.Colors.error : Theme.Colors.secondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.lg)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
        .shadow(color: Theme.Shadows.small.color,
                radius: Theme.Shadows.small.radius, x: 0, y: Theme.Shadows.small.y)
    }
}

// MARK: - Ticket Row View

private struct TicketRowView: View {
    let ticket: SupportTicket
    let onTap: () -> Void

    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: ticket.categoryEnum.icon)
                    .font(.system(size: 20))
                    .foregroundColor(Theme.Colors.primaryText)
                    .frame(width: 28)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack {
                        Text(ticket.ticketNumber)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                        Spacer()
                        Text(ticket.statusEnum.displayName)
                            .font(Theme.Typography.caption.weight(.semibold))
                            .foregroundColor(ticket.statusEnum.color)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, 3)
                            .background(ticket.statusEnum.color.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Text(ticket.subject)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundColor(Theme.Colors.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: Theme.Spacing.md) {
                        Label(Self.df.string(from: ticket.updatedAt), systemImage: "clock")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.tertiaryText)
                        if ticket.messageCount > 0 {
                            Label("\(ticket.messageCount)", systemImage: "bubble.left")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.tertiaryText)
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(UIColor.systemGray3))
                    .padding(.top, 4)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
            .shadow(color: Theme.Shadows.small.color,
                    radius: Theme.Shadows.small.radius, x: 0, y: Theme.Shadows.small.y)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ticket Detail View

struct SupportTicketDetailView: View {
    let ticketNumber: String
    @StateObject private var store = SupportStore.shared
    @State private var messageText = ""
    @State private var showCloseConfirm = false
    @FocusState private var replyFocused: Bool

    private var ticket: SupportTicket? {
        store.tickets.first { $0.ticketNumber == ticketNumber }
    }

    private var isClosed: Bool {
        ticket?.statusEnum.isActive == false
    }

    var body: some View {
        VStack(spacing: 0) {
            if let ticket {
                ticketHeader(ticket)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(Theme.Colors.cardBackground)

                Divider()

                messageThread(ticket: ticket)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if !isClosed {
                    if let err = store.sendMessageError {
                        Text(err.errorDescription ?? "Failed to send message.")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.top, Theme.Spacing.sm)
                    }
                    replyBar
                }
            } else {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.Colors.background)
        .navigationTitle(ticketNumber)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let ticket, ticket.statusEnum.isActive {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        replyFocused = false
                        showCloseConfirm = true
                    } label: {
                        Text("Close")
                            .font(Theme.Typography.subheadline.weight(.semibold))
                            .foregroundColor(Theme.Colors.error)
                    }
                    .disabled(store.isClosingTicket)
                }
            }
        }
        .alert("Close Ticket", isPresented: $showCloseConfirm) {
            Button("Close Ticket", role: .destructive) {
                Task { await store.closeTicket(ticketNumber: ticketNumber) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to close this ticket? You can still view it, but no new messages can be sent.")
        }
        .onAppear {
            store.clearMessages()
            Task {
                async let detail: () = store.fetchTicketDetail(ticketNumber: ticketNumber)
                async let messages: () = store.fetchMessages(ticketNumber: ticketNumber)
                await detail
                await messages
            }
        }
        .onDisappear {
            store.clearMessages()
        }
    }

    // MARK: - Ticket Header

    private func ticketHeader(_ ticket: SupportTicket) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(ticket.subject)
                        .font(Theme.Typography.headlineSemibold)
                        .foregroundColor(Theme.Colors.primaryText)
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: ticket.categoryEnum.icon)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.secondaryText)
                        Text(ticket.categoryEnum.displayName)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.secondaryText)
                    }
                }
                Spacer()
                Text(ticket.statusEnum.displayName)
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundColor(ticket.statusEnum.color)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(ticket.statusEnum.color.opacity(0.12))
                    .clipShape(Capsule())
            }

            Divider()

            if let agentName = ticket.assignedToName {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "person.fill.checkmark")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.success)
                    Text("Assigned to \(agentName)")
                        .font(Theme.Typography.caption.weight(.medium))
                        .foregroundColor(Theme.Colors.success)
                }
            } else {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text("Waiting to be assigned to a support agent")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
        }
    }

    // MARK: - Message Thread

    private func messageThread(ticket: SupportTicket) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.md) {
                    if store.isLoadingMessages {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        ForEach(store.selectedMessages) { msg in
                            MessageBubbleView(message: msg)
                        }
                    }

                    if let err = store.closeTicketError {
                        Text(err.errorDescription ?? "")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.error)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
            }
            .onChange(of: store.selectedMessages.count) { _, _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: store.isLoadingMessages) { _, loading in
                if !loading {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Reply Bar

    private var replyBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
                TextField("Reply...", text: $messageText, axis: .vertical)
                    .font(Theme.Typography.body)
                    .lineLimit(1...5)
                    .focused($replyFocused)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                    .disabled(store.isSendingMessage)

                let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                Button {
                    guard !trimmed.isEmpty else { return }
                    let text = trimmed
                    messageText = ""
                    Task { await store.sendMessage(ticketNumber: ticketNumber, message: text) }
                } label: {
                    if store.isSendingMessage {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 36, height: 36)
                .background(trimmed.isEmpty
                            ? Theme.Colors.buttonPrimary.opacity(0.4)
                            : Theme.Colors.buttonPrimary)
                .clipShape(Circle())
                .disabled(trimmed.isEmpty || store.isSendingMessage)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.cardBackground)
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubbleView: View {
    let message: TicketMessage

    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short; return f
    }()

    private var isUser: Bool {
        guard let senderId = message.senderId,
              let currentUserId = AuthStore.shared.currentUser?.id
        else { return false }
        return senderId == currentUserId
    }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: Theme.Spacing.xs) {
            // Sender name + time
            HStack(spacing: 4) {
                if !isUser {
                    Text(message.senderName ?? "Support")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.secondaryText)
                    Text("·")
                        .foregroundColor(Theme.Colors.tertiaryText)
                }
                Text(Self.df.string(from: message.createdAt))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.tertiaryText)
                if isUser {
                    Text("·")
                        .foregroundColor(Theme.Colors.tertiaryText)
                    Text("You")
                        .font(Theme.Typography.caption.weight(.semibold))
                        .foregroundColor(Theme.Colors.secondaryText)
                }
            }
            // Bubble
            HStack {
                if isUser { Spacer(minLength: 60) }
                Text(message.body)
                    .font(Theme.Typography.body)
                    .foregroundColor(isUser ? .white : Theme.Colors.primaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(isUser ? Theme.Colors.buttonPrimary : Theme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
                if !isUser { Spacer(minLength: 60) }
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

// MARK: - New Ticket View

struct NewTicketView: View {
    let onCreated: (SupportTicket) -> Void

    @StateObject private var store = SupportStore.shared
    @State private var subject = ""
    @State private var description = ""
    @State private var selectedCategory: TicketCategory = .other
    @FocusState private var descriptionFocused: Bool

    private var isValid: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                // Category
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    fieldLabel("Category")
                    categoryPicker
                }

                // Subject
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    fieldLabel("Subject")
                    TextField("Brief summary of your issue", text: $subject)
                        .font(Theme.Typography.body)
                        .padding(Theme.Spacing.md)
                        .background(Theme.Colors.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                }

                // Description
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    fieldLabel("Description")
                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("Describe your issue in detail...")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.tertiaryText)
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.md)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $description)
                            .font(Theme.Typography.body)
                            .focused($descriptionFocused)
                            .frame(minHeight: 140)
                            .padding(Theme.Spacing.sm)
                            .scrollContentBackground(.hidden)
                    }
                    .background(Theme.Colors.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.small))
                }

                // Error
                if let err = store.createTicketError {
                    Text(err.errorDescription ?? "")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Submit
                Button {
                    descriptionFocused = false
                    Task {
                        guard let ticket = await store.createTicket(
                            subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: selectedCategory.rawValue
                        ) else { return }
                        onCreated(ticket)
                    }
                } label: {
                    if store.isCreatingTicket {
                        HStack(spacing: Theme.Spacing.sm) {
                            ProgressView().tint(.white)
                            Text("Submitting…")
                        }
                    } else {
                        Text("Submit Ticket")
                    }
                }
                .primaryButtonStyle(isEnabled: isValid && !store.isCreatingTicket)
                .disabled(!isValid || store.isCreatingTicket)
            }
            .padding(Theme.Spacing.xl)
        }
        .background(Theme.Colors.background)
        .navigationTitle("New Ticket")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.clearCreateError() }
        .onTapGesture { descriptionFocused = false }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typography.subheadline.weight(.semibold))
            .foregroundColor(Theme.Colors.primaryText)
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(TicketCategory.allCases, id: \.rawValue) { cat in
                    let isSelected = selectedCategory == cat
                    Button {
                        selectedCategory = cat
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 13))
                            Text(cat.displayName)
                                .font(Theme.Typography.caption.weight(.semibold))
                        }
                        .foregroundColor(isSelected ? .white : Theme.Colors.primaryText)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(isSelected
                                    ? Theme.Colors.buttonPrimary
                                    : Theme.Colors.inputBackground)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    NavigationStack {
        SupportView()
    }
}

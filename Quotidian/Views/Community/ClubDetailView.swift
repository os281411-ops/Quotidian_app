import SwiftUI
import UIKit

/// A club's chat room. Messages arrive live; members can write, share a
/// passage, or attach a book (which shows a Bookshop.org button).
/// Club details and members are behind the ⓘ button.
struct ClubDetailView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var clubs: ClubStore
    @EnvironmentObject private var safety: SafetyStore
    @EnvironmentObject private var tabBar: TabBarVisibility
    @Environment(\.dismiss) private var dismiss

    @State private var club: BookClub
    @StateObject private var room: ChatRoom

    @State private var draft = ""
    @State private var isQuote = false
    @State private var attachedBook: Book?
    @State private var showBookPicker = false
    @State private var showInfo = false
    @State private var profileToShow: ClubMember?
    @State private var reporting: ChatMessage?
    @State private var reportSent = false
    @State private var blocking: ChatMessage?
    @State private var editingReadingNow = false
    @FocusState private var isComposerFocused: Bool

    init(initialClub: BookClub) {
        _club = State(initialValue: initialClub)
        _room = StateObject(wrappedValue: ChatRoom(clubID: initialClub.id))
    }

    private var myRole: ClubMember.Role? { clubs.role(in: club) }
    private var isMember: Bool { myRole != nil }
    private var canModerate: Bool { myRole == .owner || myRole == .moderator }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if club.hasReadingNow || canModerate {
                    ReadingNowBanner(club: club, canEdit: canModerate) {
                        if canModerate { editingReadingNow = true } else { showInfo = true }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
                }

                messageList

                CommunityErrorText(message: room.errorMessage ?? clubs.errorMessage)
                    .padding(.horizontal, 20)

                if auth.isBanned {
                    bannedNotice
                } else if isMember {
                    ChatComposer(
                        text: $draft,
                        isQuote: $isQuote,
                        attachedBook: $attachedBook,
                        isFocused: $isComposerFocused,
                        isSending: room.isSending,
                        onPickBook: { showBookPicker = true },
                        onSend: send
                    )
                } else {
                    joinBar
                }
            }
            .padding(.bottom, 6)
        }
        .navigationTitle(club.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showInfo = true } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityLabel("Club info")
            }
        }
        .task {
            clubs.errorMessage = nil
            await room.start()
        }
        // The floating tab bar would cover the message box, so hide it while
        // the chat is open (it comes back when you go back).
        .onAppear { tabBar.isHidden = true }
        .onDisappear {
            tabBar.isHidden = false
            Task { await room.stop() }
        }
        .sheet(isPresented: $editingReadingNow) {
            EditReadingNowView(club: club) { updated in
                club = updated
            }
        }
        .sheet(isPresented: $showBookPicker) {
            BookPickerView(title: "Attach a Book") { book in
                attachedBook = book
            }
        }
        .sheet(isPresented: $showInfo) {
            ClubInfoView(club: $club, onLeftOrDeleted: { dismiss() })
        }
        .sheet(item: $profileToShow) { member in
            MemberProfileView(member: member, onBlockChanged: {
                Task { await room.loadLatest() }
            })
        }
        .alert(
            "Block \(blocking?.authorName ?? "this reader")?",
            isPresented: Binding(get: { blocking != nil }, set: { if !$0 { blocking = nil } }),
            presenting: blocking
        ) { message in
            Button("Block", role: .destructive) {
                Task {
                    guard let me = auth.userID else { return }
                    if await safety.block(message.authorID, me: me) {
                        await room.loadLatest()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("You won't see their messages in any club. They won't be told. You can unblock them from Account → Blocked Readers.")
        }
        .confirmationDialog(
            "Report this message?",
            isPresented: Binding(get: { reporting != nil }, set: { if !$0 { reporting = nil } }),
            titleVisibility: .visible,
            presenting: reporting
        ) { message in
            ForEach(ReportReason.allCases) { reason in
                Button(reason.label) {
                    Task {
                        guard let userID = auth.userID else { return }
                        if await room.report(message, reason: reason, userID: userID) {
                            reportSent = true
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Reports are reviewed within 24 hours.")
        }
        .alert("Thanks for reporting", isPresented: $reportSent) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We'll review it within 24 hours.")
        }
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    if room.hasOlder {
                        Button {
                            Task { await room.loadOlder() }
                        } label: {
                            if room.isLoadingOlder {
                                ProgressView().tint(Theme.accent)
                            } else {
                                Text("Load earlier messages")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.vertical, 10)
                    }

                    if room.isLoading {
                        ProgressView().tint(Theme.accent).padding(.top, 60)
                    } else if room.messages.isEmpty {
                        emptyChat
                    }

                    ForEach(Array(room.messages.enumerated()), id: \.element.id) { index, message in
                        MessageRow(
                            message: message,
                            isMine: message.authorID == auth.userID,
                            showsHeader: startsGroup(at: index),
                            onTapAuthor: { showProfile(of: message) }
                        )
                        .id(message.id)
                        .contextMenu { contextMenu(for: message) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await room.loadLatest() }
            .onChange(of: room.messages.last?.id) { _, lastID in
                guard let lastID else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
            .onChange(of: isComposerFocused) { _, focused in
                guard focused, let lastID = room.messages.last?.id else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                }
            }
        }
    }

    /// Show the name and time when the author changes or after a 10-minute gap.
    private func startsGroup(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let previous = room.messages[index - 1]
        let current = room.messages[index]
        return previous.authorID != current.authorID
            || current.createdAt.timeIntervalSince(previous.createdAt) > 600
    }

    private var emptyChat: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 32))
                .foregroundStyle(Theme.accentDim)
            Text("No messages yet")
                .font(Theme.Font.serif(19, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(isMember
                 ? "Say hello, share a passage, or attach a book you'd recommend."
                 : "Join to start the conversation.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func contextMenu(for message: ChatMessage) -> some View {
        Button {
            UIPasteboard.general.string = message.copyText
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        if message.authorID != auth.userID {
            Button {
                showProfile(of: message)
            } label: {
                Label("View Profile", systemImage: "person")
            }
            Button {
                reporting = message
            } label: {
                Label("Report", systemImage: "flag")
            }
            Button(role: .destructive) {
                blocking = message
            } label: {
                Label("Block \(message.authorName)", systemImage: "hand.raised")
            }
        }

        if message.authorID == auth.userID || canModerate {
            Button(role: .destructive) {
                Task { await room.delete(message) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func showProfile(of message: ChatMessage) {
        profileToShow = ClubMember(
            userID: message.authorID,
            role: .member,
            joinedAt: message.createdAt,
            profile: message.author
        )
    }

    // MARK: - Bottom bar

    private var bannedNotice: some View {
        Label("Your account can't send messages because it broke the house rules.", systemImage: "nosign")
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
    }

    private var joinBar: some View {
        VStack(spacing: 8) {
            CommunityPrimaryButton(title: "Join to Chat", isWorking: clubs.isWorking) {
                Task {
                    guard let userID = auth.userID else { return }
                    await clubs.join(club, userID: userID)
                }
            }
            Text("Anyone can read this club. Join to send messages.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private func send() {
        guard let userID = auth.userID else { return }
        let text = draft, quote = isQuote, book = attachedBook
        Task {
            if await room.send(text: text, asQuote: quote, book: book, userID: userID) {
                draft = ""
                isQuote = false
                attachedBook = nil
            }
        }
    }
}

// MARK: - Message row

struct MessageRow: View {
    let message: ChatMessage
    let isMine: Bool
    let showsHeader: Bool
    let onTapAuthor: () -> Void

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
            if showsHeader {
                HStack(spacing: 6) {
                    if !isMine {
                        Button(action: onTapAuthor) {
                            Text(message.authorName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(timestamp)
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, 10)
                .padding(.horizontal, 4)
            }

            HStack {
                if isMine { Spacer(minLength: 48) }
                bubble
                if !isMine { Spacer(minLength: 48) }
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.isHidden {
                Label("Hidden after reports", systemImage: "eye.slash")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(hex: 0xFF6B6B))
            }

            if let quote = message.quoteText {
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Theme.accent)
                        .frame(width: 2)
                    Text(quote)
                        .font(Theme.Font.serif(16).italic())
                        .foregroundStyle(Theme.textPrimary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let body = message.body {
                Text(body)
                    .font(.body)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            if let book = message.book {
                BookCard(book: book, compact: true)
                    .frame(maxWidth: 280)
            }

            if message.editedAt != nil {
                Text("Edited")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isMine ? Theme.accent.opacity(0.16) : Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isMine ? Theme.accent.opacity(0.25) : Theme.divider, lineWidth: 1)
        )
    }

    private var timestamp: String {
        let date = message.createdAt
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }
}

// MARK: - Composer

struct ChatComposer: View {
    @Binding var text: String
    @Binding var isQuote: Bool
    @Binding var attachedBook: Book?
    var isFocused: FocusState<Bool>.Binding
    let isSending: Bool
    let onPickBook: () -> Void
    let onSend: () -> Void

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachedBook != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let book = attachedBook {
                HStack(spacing: 10) {
                    BookCover(url: book.cover, width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(book.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        Text("Shows a Bookshop.org link")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Button { attachedBook = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .accessibilityLabel("Remove book")
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface))
            }

            if isQuote {
                Label("Sharing a passage", systemImage: "text.quote")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.leading, 4)
            }

            HStack(alignment: .bottom, spacing: 8) {
                composerButton("book", label: "Attach a book", isOn: attachedBook != nil, action: onPickBook)
                composerButton("text.quote", label: "Share a passage", isOn: isQuote) {
                    withAnimation(.easeOut(duration: 0.15)) { isQuote.toggle() }
                }

                TextField(
                    "",
                    text: $text,
                    prompt: Text(isQuote ? "Paste or type the passage…" : "Message")
                        .foregroundStyle(Theme.textSecondary.opacity(0.6)),
                    axis: .vertical
                )
                .lineLimit(1...6)
                .font(isQuote ? Theme.Font.serif(16).italic() : .body)
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.accent)
                .focused(isFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))

                Button(action: onSend) {
                    ZStack {
                        if isSending {
                            ProgressView().tint(Theme.background)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.background)
                        }
                    }
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(canSend ? Theme.accent : Theme.accent.opacity(0.3)))
                }
                .disabled(!canSend || isSending)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func composerButton(_ systemImage: String, label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isOn ? Theme.accent : Theme.textSecondary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Theme.surface))
                .overlay(Circle().stroke(isOn ? Theme.accent.opacity(0.5) : Theme.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

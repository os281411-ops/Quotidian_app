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
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @EnvironmentObject private var paywall: PaywallPresenter
    @Environment(\.dismiss) private var dismiss

    @State private var club: BookClub
    @StateObject private var room: ChatRoom
    /// Set for the Quote of the Day room: the quote being discussed.
    private let dailyQuote: Quote?

    @State private var draft = ""
    @State private var isQuote = false
    @State private var isSpoiler = false
    @State private var spoilerLabel = ""
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
        let isDaily = initialClub.id == DailyRoom.clubID
        _club = State(initialValue: initialClub)
        _room = StateObject(wrappedValue: ChatRoom(
            clubID: initialClub.id,
            roomDay: isDaily ? DailyRoom.today() : nil
        ))
        dailyQuote = isDaily ? QuoteProvider.shared.quote() : nil
    }

    private var isDaily: Bool { club.id == DailyRoom.clubID }
    private var myRole: ClubMember.Role? { clubs.role(in: club) }
    private var isMember: Bool { myRole != nil }
    private var canModerate: Bool { !isDaily && (myRole == .owner || myRole == .moderator) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if let dailyQuote {
                    DailyQuoteBanner(quote: dailyQuote)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 4)
                } else if club.hasReadingNow || canModerate {
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
                        isSpoiler: $isSpoiler,
                        spoilerLabel: $spoilerLabel,
                        suggestedSpoilerLabel: club.readingProgress,
                        placeholder: isDaily ? "What did today's quote make you think?" : "Message",
                        attachedBook: $attachedBook,
                        isFocused: $isComposerFocused,
                        isSending: room.isSending,
                        onPickBook: { showBookPicker = true },
                        onSend: send
                    )
                } else if isDaily {
                    // Joining happens automatically; this shows only if it failed.
                    CommunityPrimaryButton(title: "Join the Discussion") {
                        Task {
                            guard let userID = auth.userID else { return }
                            await clubs.ensureDailyRoomMembership(userID: userID)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                } else {
                    joinBar
                }
            }
            .padding(.bottom, 6)
        }
        .navigationTitle(isDaily ? "Today's Quote" : club.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            if !isDaily {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showInfo = true } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .accessibilityLabel("Club info")
                }
            }
        }
        .task {
            clubs.errorMessage = nil
            if isDaily, !auth.isBanned, let userID = auth.userID {
                await clubs.ensureDailyRoomMembership(userID: userID)
            }
            // Double-check membership with the server, so a club you've just
            // made or joined never asks you to "Join to Chat".
            if !isMember, !isDaily, let userID = auth.userID {
                await clubs.refreshMembership(clubID: club.id, userID: userID)
            }
            await room.start()
            if isMember, !isDaily { await clubs.markRead(clubID: club.id) }
            // A brand-new (empty) club opens ready to type.
            if isMember, !auth.isBanned, room.messages.isEmpty {
                isComposerFocused = true
            }
        }
        // The floating tab bar would cover the message box, so hide it while
        // the chat is open (it comes back when you go back).
        .onAppear { tabBar.isHidden = true }
        .onDisappear {
            tabBar.isHidden = false
            let clubID = club.id, markRead = isMember && !isDaily
            Task {
                await room.stop()
                // Anything that arrived while you were here counts as read.
                if markRead { await clubs.markRead(clubID: clubID) }
            }
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
                            isRevealed: room.revealedSpoilers.contains(message.id),
                            onTapAuthor: { showProfile(of: message) },
                            onReveal: { withAnimation(.easeOut(duration: 0.25)) { room.reveal(message) } }
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
            Text(isDaily ? "Be the first today" : "No messages yet")
                .font(Theme.Font.serif(19, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(isDaily
                 ? "Share what today's quote means to you. Everyone reading Quotidian today can join in."
                 : isMember
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

        if let quote = libraryQuote(for: message) {
            Button {
                toggleSaved(quote)
            } label: {
                if library.isSaved(quote) {
                    Label("Remove from Library", systemImage: "bookmark.slash")
                } else {
                    Label("Save to Library", systemImage: "bookmark")
                }
            }
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

    /// A shared passage as a Library quote. The ID is tied to the message, so
    /// saving it twice doesn't create duplicates.
    private func libraryQuote(for message: ChatMessage) -> Quote? {
        guard let text = message.quoteText else { return nil }
        return Quote(
            id: "club-\(message.id.uuidString.lowercased())",
            text: text,
            author: message.book?.author ?? "Unknown author",
            book: message.book?.title ?? "",
            year: "",
            about: isDaily
                ? "Shared in the Quote of the Day discussion by \(message.authorName)."
                : "Shared in \(club.name) by \(message.authorName).",
            isbn13: message.book?.isbn13
        )
    }

    /// Same rules as saving the daily quote: free accounts can keep 10.
    private func toggleSaved(_ quote: Quote) {
        if library.isSaved(quote)
            || subscriptions.isSubscribed
            || library.savedQuotes.count < LibraryStore.freeSaveLimit {
            library.toggle(quote)
        } else {
            paywall.present(.saveLimit)
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
        let text = draft, quote = isQuote, book = attachedBook, spoiler = isSpoiler, label = spoilerLabel

        // Empty the box straight away rather than after the server replies.
        // The keyboard can finish an autocorrection just after sending and
        // put the text back, so check again a moment later too.
        clearComposer()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let leftover = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            if !leftover.isEmpty, text.contains(leftover) { draft = "" }
        }

        Task {
            let sent = await room.send(text: text, asQuote: quote, book: book, spoiler: spoiler, spoilerLabel: label, userID: userID)
            // Didn't send: put it back so nothing is lost.
            if !sent, draft.isEmpty {
                draft = text
                isQuote = quote
                isSpoiler = spoiler
                spoilerLabel = label
                attachedBook = book
            }
        }
    }

    private func clearComposer() {
        draft = ""
        isQuote = false
        isSpoiler = false
        spoilerLabel = ""
        attachedBook = nil
    }
}

// MARK: - Message row

struct MessageRow: View {
    let message: ChatMessage
    let isMine: Bool
    let showsHeader: Bool
    var isRevealed = false
    let onTapAuthor: () -> Void
    var onReveal: () -> Void = {}

    /// Others' spoilers stay hidden until tapped; your own are always visible.
    private var isConcealed: Bool { message.isSpoiler && !isMine && !isRevealed }

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
        bubbleContent
            .blur(radius: isConcealed ? 9 : 0)
            .allowsHitTesting(!isConcealed)
            .overlay {
                if isConcealed {
                    Button(action: onReveal) {
                        Label(spoilerCaption + " · Tap to reveal", systemImage: "eye.slash")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Theme.surfaceElevated))
                            .overlay(Capsule().stroke(Theme.accent.opacity(0.4), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(spoilerCaption). Double-tap to reveal.")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var spoilerCaption: String {
        message.spoilerLabel.map { "Spoiler · \($0)" } ?? "Spoiler"
    }

    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.isSpoiler && !isConcealed {
                Label(spoilerCaption, systemImage: "eye.slash")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }

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
    @Binding var isSpoiler: Bool
    @Binding var spoilerLabel: String
    /// The club's Now Reading section, offered as the spoiler label.
    var suggestedSpoilerLabel: String? = nil
    var placeholder = "Message"
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

            if isSpoiler {
                HStack(spacing: 8) {
                    Image(systemName: "eye.slash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text("Spoiler")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    TextField("", text: $spoilerLabel, prompt: Text("Chapter or part (optional)").foregroundStyle(Theme.textSecondary.opacity(0.6)))
                        .font(.caption)
                        .foregroundStyle(Theme.textPrimary)
                        .tint(Theme.accent)
                        .onChange(of: spoilerLabel) { _, newValue in
                            if newValue.count > ChatRoom.spoilerLabelLimit {
                                spoilerLabel = String(newValue.prefix(ChatRoom.spoilerLabelLimit))
                            }
                        }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Theme.surface))
            }

            HStack(alignment: .bottom, spacing: 8) {
                composerButton("book", label: "Attach a book", isOn: attachedBook != nil, action: onPickBook)
                composerButton("text.quote", label: "Share a passage", isOn: isQuote) {
                    withAnimation(.easeOut(duration: 0.15)) { isQuote.toggle() }
                }
                composerButton("eye.slash", label: "Mark as spoiler", isOn: isSpoiler) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isSpoiler.toggle()
                        if isSpoiler, spoilerLabel.isEmpty, let suggested = suggestedSpoilerLabel {
                            spoilerLabel = String(suggested.prefix(ChatRoom.spoilerLabelLimit))
                        }
                    }
                }

                TextField(
                    "",
                    text: $text,
                    prompt: Text(isQuote ? "Paste or type the passage…" : placeholder)
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

// MARK: - Quote of the Day banner

/// Today's quote, pinned above the daily discussion.
struct DailyQuoteBanner: View {
    let quote: Quote
    @State private var isExpanded = false

    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            // The accent line is drawn behind the text so it only ever
            // matches the quote's height (a plain shape would stretch).
            VStack(alignment: .leading, spacing: 6) {
                Text(quote.text)
                    .font(Theme.Font.serif(16).italic())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(isExpanded ? nil : 3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(quote.hasBook ? "\(quote.author), \(quote.book)" : quote.author)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)
            .background(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.accent)
                    .frame(width: 2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.divider, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHint(isExpanded ? "Shows less" : "Shows the whole quote")
    }
}

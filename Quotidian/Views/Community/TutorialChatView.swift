import SwiftUI

/// A private, scripted chat that every reader has in My Clubs: it walks
/// through how club chat works, one feature at a time. Type "next" to get
/// the next part. Nothing here touches the server; it's all on this phone.
enum TutorialChat {
    static let clubID = UUID(uuidString: "00000000-0000-4000-8000-0000000000aa")!
    private static let guideID = UUID(uuidString: "00000000-0000-4000-8000-0000000000ab")!

    /// Stand-in club so it can sit in the club list and open like a chat.
    static let club = BookClub(
        id: clubID,
        name: "Welcome to Bookclub",
        description: "A quick tour of club chat. Only you can see this.",
        isPrivate: true,
        ownerID: nil,
        createdAt: Date(timeIntervalSince1970: 0)
    )

    /// What the guide is "currently reading" on its practice profile.
    static let guideReading = Book(
        id: UUID(uuidString: "00000000-0000-4000-8000-0000000000ae")!,
        title: "Minions: The Junior Novel",
        author: "Sadie Chesterfield",
        isbn13: "9780316299954",
        openLibraryID: nil,
        coverURL: "https://covers.openlibrary.org/b/isbn/9780316299954-M.jpg?default=false"
    )

    static let stepKey = "tutorial.step"
    static let completedKey = "tutorial.completed"

    static let guide = MemberProfile(username: "quotidian", displayName: "Quotidian Guide")

    static let sampleBook = Book(
        id: UUID(uuidString: "00000000-0000-4000-8000-0000000000ac")!,
        title: "Pride and Prejudice",
        author: "Jane Austen",
        isbn13: "9780143138730",
        openLibraryID: nil,
        coverURL: "https://covers.openlibrary.org/b/isbn/9780143138730-M.jpg"
    )

    /// One thing the guide "sends".
    enum Item {
        case text(String)
        case passage(String, book: Book?)
        case book(Book, String)
        case spoiler(String, label: String)
        case dailyRoomButton
    }

    /// The tour, one step per "next".
    static let steps: [[Item]] = [
        [
            .text("Hi! Welcome to Bookclub."),
            .text("Clubs are group chats for readers. A club can be about one book, an author, a genre, a character, anything you like."),
            .text("This chat is just for you, so nothing here is seen by anyone else. Type next to start the tour."),
        ],
        [
            .text("Writing a message works like any chat: type in the box below and tap the arrow."),
            .text("Tap someone's name above their message to see their profile and what they're currently reading. Try it: tap \u{201C}Quotidian Guide\u{201D} above this message."),
            .text("Type next when you've had a look."),
        ],
        [
            .text("Want to share a line from a book? Tap the quote button next to the message box (the one with the lines), then type or paste the passage."),
            .passage("It is a truth universally acknowledged, that a single man in possession of a good fortune, must be in want of a wife.", book: sampleBook),
            .text("Passages stand out from normal chat, like the one above. Try sending one if you like, then type next."),
        ],
        [
            .text("To recommend a book, tap the book button and search for it. It's added as a card like this:"),
            .book(sampleBook, "Worth a read if you like sharp, funny dialogue."),
            .text("Tap the card to find it on Bookshop.org, which supports independent bookshops. Type next to carry on."),
        ],
        [
            .text("Talking about something that happens later in a book? Tap the eye button to mark your message as a spoiler."),
            .text("Everyone else sees it blurred until they choose to reveal it. Tap this one to try:"),
            .spoiler("The butler did it.", label: "Final chapter"),
            .text("You can add a label like \u{201C}Ch. 12\u{201D} so people know how far into the book it is. Type next."),
        ],
        [
            .text("Club owners can pin what everyone's reading right now, like \u{201C}Chapters 1\u{2013}5, by Friday\u{201D}. It shows at the top of the club's chat, and fills in the label on spoilers for you."),
            .text("When a club has new messages, it shows a number in My Clubs and the Bookclub tab gets a small dot."),
            .text("Type next."),
        ],
        [
            .text("Press and hold any message for more options: copy it, save a shared passage to your Library, view the person's profile, or report and block them."),
            .text("Reports are reviewed within 24 hours, and blocked readers disappear from every club for you."),
            .text("Nearly done. Type next for the last one."),
        ],
        [
            .text("Every day there's one big conversation about the day's quote, open to everyone who reads Quotidian."),
            .dailyRoomButton,
            .text("Look for this button at the bottom of Bookclub, or tap \u{201C}Discuss today's quote\u{201D} on Today. Tap it now to join in."),
            .text("That's the tour! It stays at the bottom of My Clubs if you ever want to look back. Enjoy Bookclub."),
        ],
    ]

    static var lastStep: Int { steps.count - 1 }

    fileprivate static func message(_ item: Item, mine: Bool = false, authorID: UUID? = nil) -> ChatMessage? {
        func make(body: String? = nil, quote: String? = nil, book: Book? = nil, spoiler: Bool = false, label: String? = nil) -> ChatMessage {
            ChatMessage(
                id: UUID(),
                clubID: clubID,
                authorID: authorID ?? guideID,
                body: body,
                quoteText: quote,
                isHidden: false,
                isSpoiler: spoiler,
                spoilerLabel: label,
                createdAt: Date(),
                editedAt: nil,
                author: mine ? nil : guide,
                book: book
            )
        }
        switch item {
        case .text(let text): return make(body: text)
        case .passage(let text, let book): return make(quote: text, book: book)
        case .book(let book, let text): return make(body: text, book: book)
        case .spoiler(let text, let label): return make(body: text, spoiler: true, label: label)
        case .dailyRoomButton: return nil
        }
    }
}

struct TutorialChatView: View {
    /// Opens today's Quote of the Day room (from the last step).
    let onOpenDailyRoom: () -> Void

    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var tabBar: TabBarVisibility

    @AppStorage(TutorialChat.stepKey) private var savedStep = 0
    @AppStorage(TutorialChat.completedKey) private var completed = false

    private struct Entry: Identifiable {
        enum Kind {
            case message(ChatMessage)
            case dailyRoomButton
        }
        let id = UUID()
        let kind: Kind
    }

    @State private var entries: [Entry] = []
    @State private var revealed: Set<UUID> = []
    @State private var isTyping = false

    @State private var draft = ""
    @State private var isQuote = false
    @State private var isSpoiler = false
    @State private var spoilerLabel = ""
    @State private var attachedBook: Book?
    @State private var showBookPicker = false
    @State private var showGuideProfile = false
    @FocusState private var isComposerFocused: Bool

    private var me: UUID { auth.userID ?? UUID(uuidString: "00000000-0000-4000-8000-0000000000ad")! }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                messageList

                ChatComposer(
                    text: $draft,
                    isQuote: $isQuote,
                    isSpoiler: $isSpoiler,
                    spoilerLabel: $spoilerLabel,
                    suggestedSpoilerLabel: nil,
                    placeholder: completed ? "Message" : "Type \u{201C}next\u{201D} to continue",
                    attachedBook: $attachedBook,
                    isFocused: $isComposerFocused,
                    isSending: false,
                    onPickBook: { showBookPicker = true },
                    onSend: send
                )
            }
            .padding(.bottom, 6)
        }
        .navigationTitle("Welcome to Bookclub")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .onAppear {
            tabBar.isHidden = true
            if entries.isEmpty { rebuildHistory() }
        }
        .onDisappear { tabBar.isHidden = false }
        .sheet(isPresented: $showBookPicker) {
            BookPickerView(title: "Attach a Book") { book in
                attachedBook = book
            }
        }
        .sheet(isPresented: $showGuideProfile) {
            GuideProfileSheet()
        }
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    Label("Only you can see this chat", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.vertical, 10)

                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        row(for: entry, at: index)
                            .id(entry.id)
                    }

                    if isTyping {
                        HStack {
                            Text("Quotidian Guide is typing\u{2026}")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 4)
                                .padding(.top, 8)
                            Spacer()
                        }
                        .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: entries.count) { _, _ in
                guard let last = entries.last?.id else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last, anchor: .bottom) }
            }
            .onChange(of: isTyping) { _, typing in
                guard typing else { return }
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("typing", anchor: .bottom) }
            }
        }
    }

    @ViewBuilder
    private func row(for entry: Entry, at index: Int) -> some View {
        switch entry.kind {
        case .message(let message):
            MessageRow(
                message: message,
                isMine: message.authorID == me,
                showsHeader: startsGroup(at: index),
                isRevealed: revealed.contains(message.id),
                onTapAuthor: { if message.authorID != me { showGuideProfile = true } },
                onReveal: { withAnimation(.easeOut(duration: 0.25)) { _ = revealed.insert(message.id) } }
            )
        case .dailyRoomButton:
            HStack {
                VStack(spacing: 8) {
                    DailyRoomButton(action: onOpenDailyRoom)
                    Text("Quote of the Day")
                        .font(.caption2.weight(.semibold))
                        .trackedCaps(1)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.divider, lineWidth: 1))
                Spacer(minLength: 48)
            }
            .padding(.vertical, 4)
        }
    }

    /// Show the name only when the sender changes.
    private func startsGroup(at index: Int) -> Bool {
        guard index > 0 else { return true }
        func author(_ entry: Entry) -> UUID? {
            if case .message(let message) = entry.kind { return message.authorID }
            return nil
        }
        return author(entries[index - 1]) != author(entries[index])
    }

    // MARK: - Script

    /// Shows everything up to where the reader got to last time.
    private func rebuildHistory() {
        let step = min(savedStep, TutorialChat.lastStep)
        for index in 0...step {
            TutorialChat.steps[index].forEach(appendGuide)
            if index < step { appendMine(body: "next") }
        }
    }

    private func appendGuide(_ item: TutorialChat.Item) {
        if case .dailyRoomButton = item {
            entries.append(Entry(kind: .dailyRoomButton))
        } else if let message = TutorialChat.message(item) {
            entries.append(Entry(kind: .message(message)))
        }
    }

    private func appendMine(body: String?, quote: String? = nil, book: Book? = nil, spoiler: Bool = false, label: String? = nil) {
        let message = ChatMessage(
            id: UUID(),
            clubID: TutorialChat.clubID,
            authorID: me,
            body: body,
            quoteText: quote,
            isHidden: false,
            isSpoiler: spoiler,
            spoilerLabel: label,
            createdAt: Date(),
            editedAt: nil,
            author: auth.profile.map { MemberProfile(username: $0.username, displayName: $0.displayName) },
            book: book
        )
        entries.append(Entry(kind: .message(message)))
    }

    /// The guide "types" each line with a short pause, like a real chat.
    private func play(_ items: [TutorialChat.Item]) async {
        for item in items {
            isTyping = true
            try? await Task.sleep(for: .milliseconds(750))
            isTyping = false
            withAnimation(.easeOut(duration: 0.2)) { appendGuide(item) }
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || attachedBook != nil, !isTyping else { return }

        // Show what they sent, styled the way they chose (passage, spoiler, book).
        appendMine(
            body: isQuote || text.isEmpty ? nil : text,
            quote: isQuote && !text.isEmpty ? text : nil,
            book: attachedBook,
            spoiler: isSpoiler,
            label: isSpoiler && !spoilerLabel.isEmpty ? spoilerLabel : nil
        )
        draft = ""
        isQuote = false
        isSpoiler = false
        spoilerLabel = ""
        attachedBook = nil

        let wantsNext = text.lowercased().trimmingCharacters(in: .punctuationCharacters) == "next"
        Task {
            if wantsNext && savedStep < TutorialChat.lastStep {
                savedStep += 1
                await play(TutorialChat.steps[savedStep])
                if savedStep == TutorialChat.lastStep { completed = true }
            } else if wantsNext {
                await play([.text("That's everything! Head back to Bookclub to find a club, or tap the Quote of the Day button to join today's discussion.")])
            } else {
                await play([.text(completed
                    ? "Only you can see this chat. Head back to Bookclub to talk with other readers."
                    : "Nice! Only you can see that. Type next when you're ready.")])
            }
        }
    }
}

/// The guide's profile: looks like a real member's profile, for practice.
private struct GuideProfileSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            MemberAvatar(name: "Quotidian Guide", size: 64)
                            Text("Quotidian Guide")
                                .font(Theme.Font.serif(24, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("@quotidian")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Currently Reading")
                                .font(.caption.weight(.semibold))
                                .trackedCaps(1.5)
                                .foregroundStyle(Theme.textSecondary)
                            BookCard(book: TutorialChat.guideReading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))

                        Label("On other readers' profiles you'll also find Block and Report. Set your own Currently Reading from your account (the person icon at the top of Bookclub).", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDetents([.fraction(0.62), .large])
    }
}

/// The tutorial's spot in My Clubs.
struct TutorialRow: View {
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.surfaceElevated))
            VStack(alignment: .leading, spacing: 3) {
                Text(isComplete ? "Bookclub tour" : "Welcome to Bookclub")
                    .font(Theme.Font.serif(16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(isComplete ? "See how club chat works again" : "A quick tour of how club chat works")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if !isComplete {
                Text("New")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.accent))
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
        .overlay(alignment: .leading) {
            if !isComplete {
                // Gold edge marks it as new, matching unread clubs.
                UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 14, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: 3)
            }
        }
        .contentShape(Rectangle())
    }
}

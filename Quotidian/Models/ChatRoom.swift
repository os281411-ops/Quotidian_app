import Combine
import Foundation
import Supabase

/// One message in a club chat: text, a quoted passage, an attached book,
/// or any mix of those.
nonisolated struct ChatMessage: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let clubID: UUID
    let authorID: UUID
    var body: String?
    var quoteText: String?
    var isHidden: Bool
    /// Marked as a spoiler: blurred for others until they tap to reveal.
    var isSpoiler: Bool
    var spoilerLabel: String?
    let createdAt: Date
    var editedAt: Date?
    let author: MemberProfile?
    let book: Book?

    enum CodingKeys: String, CodingKey {
        case id
        case clubID = "club_id"
        case authorID = "author_id"
        case body
        case quoteText = "quote_text"
        case isHidden = "is_hidden"
        case isSpoiler = "is_spoiler"
        case spoilerLabel = "spoiler_label"
        case createdAt = "created_at"
        case editedAt = "edited_at"
        case author
        case book
    }

    static let columns =
        "id, club_id, author_id, body, quote_text, is_hidden, is_spoiler, spoiler_label, created_at, edited_at, " +
        "author:profiles(username, display_name), " +
        "book:books(\(Book.columns))"

    var authorName: String {
        author?.displayName ?? author?.username.map { "@\($0)" } ?? "Reader"
    }

    /// Text to put on the clipboard.
    var copyText: String {
        [quoteText.map { "\u{201C}\($0)\u{201D}" }, body, book.map { "\($0.title) – \($0.bookshopURL.absoluteString)" }]
            .compactMap { $0 }
            .joined(separator: "\n")
    }
}

private nonisolated struct NewChatMessage: Encodable, Sendable {
    let clubID: UUID
    let authorID: UUID
    let body: String?
    let quoteText: String?
    let bookID: UUID?
    let isSpoiler: Bool
    let spoilerLabel: String?

    enum CodingKeys: String, CodingKey {
        case clubID = "club_id"
        case authorID = "author_id"
        case body
        case quoteText = "quote_text"
        case bookID = "book_id"
        case isSpoiler = "is_spoiler"
        case spoilerLabel = "spoiler_label"
    }
}

private nonisolated struct NewReport: Encodable, Sendable {
    let reporterID: UUID
    let messageID: UUID
    let reason: String

    enum CodingKeys: String, CodingKey {
        case reporterID = "reporter_id"
        case messageID = "message_id"
        case reason
    }
}

/// Reasons people can give when reporting. Raw values match the database.
enum ReportReason: String, CaseIterable, Identifiable {
    case spam, harassment, hate, sexual, violence, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spam: "Spam"
        case .harassment: "Harassment or bullying"
        case .hate: "Hate speech"
        case .sexual: "Sexual content"
        case .violence: "Violence or threats"
        case .other: "Something else"
        }
    }
}

/// The live chat for one club. Loads recent messages, then listens for new,
/// edited and deleted ones while the chat is open.
@MainActor
final class ChatRoom: ObservableObject {
    let clubID: UUID

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingOlder = false
    @Published private(set) var hasOlder = false
    @Published private(set) var isSending = false
    /// Spoilers this person has tapped to reveal (this session only).
    @Published private(set) var revealedSpoilers: Set<UUID> = []
    @Published var errorMessage: String?

    private static let pageSize = 50
    private var channel: RealtimeChannelV2?
    private var listeners: [Task<Void, Never>] = []

    init(clubID: UUID) {
        self.clubID = clubID
    }

    // MARK: - Lifecycle

    func start() async {
        await loadLatest()
        await subscribe()
    }

    func stop() async {
        listeners.forEach { $0.cancel() }
        listeners = []
        if let channel {
            await supabase.removeChannel(channel)
            self.channel = nil
        }
    }

    // MARK: - Loading

    func loadLatest() async {
        do {
            let latest: [ChatMessage] = try await supabase
                .from("messages")
                .select(ChatMessage.columns)
                .eq("club_id", value: clubID)
                .order("created_at", ascending: false)
                .limit(Self.pageSize)
                .execute()
                .value
            messages = latest.reversed()
            hasOlder = latest.count == Self.pageSize
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load messages. Pull down to try again."
        }
        isLoading = false
    }

    func loadOlder() async {
        guard hasOlder, !isLoadingOlder, let oldest = messages.first else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }

        do {
            let older: [ChatMessage] = try await supabase
                .from("messages")
                .select(ChatMessage.columns)
                .eq("club_id", value: clubID)
                .lt("created_at", value: oldest.createdAt)
                .order("created_at", ascending: false)
                .limit(Self.pageSize)
                .execute()
                .value
            let known = Set(messages.map(\.id))
            messages.insert(contentsOf: older.reversed().filter { !known.contains($0.id) }, at: 0)
            hasOlder = older.count == Self.pageSize
        } catch {
            errorMessage = "Couldn't load older messages."
        }
    }

    // MARK: - Live updates

    private func subscribe() async {
        guard channel == nil else { return }
        let channel = supabase.channel("club-chat-\(clubID.uuidString.lowercased())")

        let inserts = channel.postgresChange(
            InsertAction.self, schema: "public", table: "messages",
            filter: .eq("club_id", value: clubID)
        )
        let updates = channel.postgresChange(
            UpdateAction.self, schema: "public", table: "messages",
            filter: .eq("club_id", value: clubID)
        )
        // Delete events can't be filtered by club; unknown IDs are ignored.
        let deletes = channel.postgresChange(DeleteAction.self, schema: "public", table: "messages")

        self.channel = channel
        try? await channel.subscribeWithError()

        listeners = [
            Task { [weak self] in
                for await action in inserts {
                    await self?.refreshMessage(idString: action.record["id"]?.stringValue)
                }
            },
            Task { [weak self] in
                for await action in updates {
                    await self?.refreshMessage(idString: action.record["id"]?.stringValue)
                }
            },
            Task { [weak self] in
                for await action in deletes {
                    self?.removeMessage(idString: action.oldRecord["id"]?.stringValue)
                }
            },
        ]
    }

    /// Re-reads one message (with its author and book) and adds, replaces
    /// or removes it. Removing covers messages that became hidden or blocked.
    private func refreshMessage(idString: String?) async {
        guard let idString, let id = UUID(uuidString: idString) else { return }
        let fresh: ChatMessage? = try? await supabase
            .from("messages")
            .select(ChatMessage.columns)
            .eq("id", value: id)
            .single()
            .execute()
            .value

        if let fresh {
            upsert(fresh)
        } else {
            messages.removeAll { $0.id == id }
        }
    }

    private func removeMessage(idString: String?) {
        guard let idString, let id = UUID(uuidString: idString) else { return }
        messages.removeAll { $0.id == id }
    }

    private func upsert(_ message: ChatMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
        } else {
            messages.append(message)
            messages.sort { $0.createdAt < $1.createdAt }
        }
    }

    // MARK: - Sending and moderating

    /// Returns true when the message was sent.
    @discardableResult
    func send(text: String, asQuote: Bool, book: Book?, spoiler: Bool = false, spoilerLabel: String? = nil, userID: UUID) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || book != nil else { return false }

        isSending = true
        defer { isSending = false }
        errorMessage = nil

        let message = NewChatMessage(
            clubID: clubID,
            authorID: userID,
            body: asQuote || trimmed.isEmpty ? nil : String(trimmed.prefix(2000)),
            quoteText: asQuote && !trimmed.isEmpty ? String(trimmed.prefix(1000)) : nil,
            bookID: book?.id,
            isSpoiler: spoiler,
            spoilerLabel: spoiler ? Self.cleanSpoilerLabel(spoilerLabel) : nil
        )

        do {
            let sent: ChatMessage = try await supabase
                .from("messages")
                .insert(message, returning: .representation)
                .select(ChatMessage.columns)
                .single()
                .execute()
                .value
            upsert(sent)
            return true
        } catch let error as PostgrestError {
            errorMessage = Self.message(for: error)
            return false
        } catch {
            errorMessage = "Couldn't send. Check your connection and try again."
            return false
        }
    }

    /// Posts a message to a club without opening its chat (used by Share to a Club).
    static func post(
        clubID: UUID,
        userID: UUID,
        body: String?,
        quote: String?,
        bookID: UUID?
    ) async throws {
        let trimmedBody = body?.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try await supabase
            .from("messages")
            .insert(NewChatMessage(
                clubID: clubID,
                authorID: userID,
                body: (trimmedBody?.isEmpty ?? true) ? nil : String(trimmedBody!.prefix(2000)),
                quoteText: quote.map { String($0.prefix(1000)) },
                bookID: bookID,
                isSpoiler: false,
                spoilerLabel: nil
            ))
            .execute()
    }

    /// Error text for a failed send, for screens outside the chat.
    static func sendErrorMessage(for error: Error) -> String {
        if let error = error as? PostgrestError { return message(for: error) }
        return "Couldn't send. Check your connection and try again."
    }

    func reveal(_ message: ChatMessage) {
        revealedSpoilers.insert(message.id)
    }

    static let spoilerLabelLimit = 40

    private static func cleanSpoilerLabel(_ label: String?) -> String? {
        guard let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(spoilerLabelLimit))
    }

    func delete(_ message: ChatMessage) async {
        do {
            _ = try await supabase
                .from("messages")
                .delete()
                .eq("id", value: message.id)
                .execute()
            messages.removeAll { $0.id == message.id }
        } catch {
            errorMessage = "Couldn't delete that message."
        }
    }

    /// Returns true when the report was filed.
    @discardableResult
    func report(_ message: ChatMessage, reason: ReportReason, userID: UUID) async -> Bool {
        do {
            _ = try await supabase
                .from("reports")
                .insert(NewReport(reporterID: userID, messageID: message.id, reason: reason.rawValue))
                .execute()
            return true
        } catch {
            errorMessage = "Couldn't send your report. Please try again."
            return false
        }
    }

    private static func message(for error: PostgrestError) -> String {
        switch (error.code ?? "", error.hint ?? "") {
        case (_, "word_filter"): return "That contains language that isn't allowed in Bookclub."
        case (_, "rate_limit"):  return "You're sending messages too quickly. Wait a minute and try again."
        case ("42501", _):       return "Join the club to send messages."
        default:                 return "Couldn't send. Please try again."
        }
    }
}

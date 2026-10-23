import Foundation

/// A row from `book_clubs`, with its member count embedded.
///
/// A club isn't tied to a book: it can be about one book, an author, a genre,
/// a character, anything. Each post says which book its quote is from.
nonisolated struct BookClub: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var description: String?
    var isPrivate: Bool
    var ownerID: UUID?
    var createdAt: Date
    /// PostgREST returns `club_members(count)` as `[{ "count": n }]`.
    var memberCountRows: [CountRow]?

    // "Now Reading": set by owners/moderators. All optional.
    var readingBook: Book?
    var readingProgress: String?
    /// "yyyy-MM-dd" (a plain date, no time).
    var readingUntil: String?
    var readingUpdatedAt: Date?

    var memberCount: Int { memberCountRows?.first?.count ?? 0 }

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case isPrivate = "is_private"
        case ownerID = "owner_id"
        case createdAt = "created_at"
        case memberCountRows = "club_members"
        case readingBook = "reading_book"
        case readingProgress = "reading_progress"
        case readingUntil = "reading_until"
        case readingUpdatedAt = "reading_updated_at"
    }

    /// Columns to request whenever clubs are loaded, so every screen gets the same shape.
    static let columns =
        "id, name, description, is_private, owner_id, created_at, club_members(count), " +
        "reading_progress, reading_until, reading_updated_at, reading_book:books(\(Book.columns))"

    static let readingProgressLimit = 80

    var hasReadingNow: Bool { readingBook != nil || readingProgress != nil }

    /// e.g. "Chapters 1–5 · Middlemarch"
    var readingSummary: String? {
        let parts = [readingProgress, readingBook?.title].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var readingUntilDate: Date? {
        guard let readingUntil else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: readingUntil)
    }

    /// e.g. "by Thu 30 Oct"
    var readingDeadlineText: String? {
        readingUntilDate.map { "by " + $0.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }
    }

    static let nameLimit = 3...60
    static let descriptionLimit = 500
}

nonisolated struct CountRow: Codable, Hashable, Sendable {
    let count: Int
}

/// Someone's membership of a club, with their public profile embedded.
nonisolated struct ClubMember: Codable, Hashable, Identifiable, Sendable {
    enum Role: String, Codable, Sendable {
        case owner, moderator, member

        var label: String {
            switch self {
            case .owner: "Owner"
            case .moderator: "Moderator"
            case .member: "Member"
            }
        }
    }

    let userID: UUID
    let role: Role
    let joinedAt: Date
    let profile: MemberProfile?

    var id: UUID { userID }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case role
        case joinedAt = "joined_at"
        case profile
    }

    static let columns =
        "user_id, role, joined_at, " +
        "profile:profiles(username, display_name, currently_reading:books(\(Book.columns)))"
}

nonisolated struct MemberProfile: Codable, Hashable, Sendable {
    let username: String?
    let displayName: String?
    /// Only filled in where the query asks for it (e.g. the members list).
    var currentlyReading: Book? = nil

    enum CodingKeys: String, CodingKey {
        case username
        case displayName = "display_name"
        case currentlyReading = "currently_reading"
    }
}

/// Just the bits of a membership needed to know which clubs you're in.
nonisolated struct MembershipRow: Codable, Sendable {
    let clubID: UUID
    let role: ClubMember.Role

    enum CodingKeys: String, CodingKey {
        case clubID = "club_id"
        case role
    }
}

/// Body sent when creating a club.
nonisolated struct NewBookClub: Encodable, Sendable {
    let name: String
    let description: String?
    let isPrivate: Bool
    let ownerID: UUID

    enum CodingKeys: String, CodingKey {
        case name, description
        case isPrivate = "is_private"
        case ownerID = "owner_id"
    }
}

nonisolated struct NewMembership: Encodable, Sendable {
    let clubID: UUID
    let userID: UUID

    enum CodingKeys: String, CodingKey {
        case clubID = "club_id"
        case userID = "user_id"
    }
}

/// Body sent when owners/moderators change "Now Reading". Sends explicit
/// nulls so clearing a field really clears it.
nonisolated struct ReadingNowUpdate: Encodable, Sendable {
    let bookID: UUID?
    let progress: String?
    let until: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case bookID = "reading_book_id"
        case progress = "reading_progress"
        case until = "reading_until"
        case updatedAt = "reading_updated_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bookID, forKey: .bookID)
        try container.encode(progress, forKey: .progress)
        try container.encode(until, forKey: .until)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

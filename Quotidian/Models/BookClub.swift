import Foundation

/// A row from `book_clubs`, with its current book and member count embedded.
nonisolated struct BookClub: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var description: String?
    var isPrivate: Bool
    var ownerID: UUID?
    var createdAt: Date
    var currentBook: ClubBook?
    /// PostgREST returns `club_members(count)` as `[{ "count": n }]`.
    var memberCountRows: [CountRow]?

    var memberCount: Int { memberCountRows?.first?.count ?? 0 }

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case isPrivate = "is_private"
        case ownerID = "owner_id"
        case createdAt = "created_at"
        case currentBook = "current_book"
        case memberCountRows = "club_members"
    }

    /// Columns to request whenever clubs are loaded, so every screen gets the same shape.
    static let columns =
        "id, name, description, is_private, owner_id, created_at, " +
        "current_book:books(id, title, author, cover_url), " +
        "club_members(count)"

    static let nameLimit = 3...60
    static let descriptionLimit = 500
}

nonisolated struct CountRow: Codable, Hashable, Sendable {
    let count: Int
}

/// The book a club is currently reading.
nonisolated struct ClubBook: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var author: String?
    var coverURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, author
        case coverURL = "cover_url"
    }
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

    static let columns = "user_id, role, joined_at, profile:profiles(username, display_name)"
}

nonisolated struct MemberProfile: Codable, Hashable, Sendable {
    let username: String?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case username
        case displayName = "display_name"
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

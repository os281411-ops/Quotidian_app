import Foundation

/// A row from the `profiles` table: the public face of a community member.
nonisolated struct CommunityProfile: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var username: String?
    var displayName: String?
    var avatarURL: String?
    var acceptedGuidelinesAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case acceptedGuidelinesAt = "accepted_guidelines_at"
    }

    /// Same rule the database enforces: 3–20 characters, lowercase letters,
    /// numbers and underscores.
    static func isValidUsername(_ name: String) -> Bool {
        name.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil
    }
}

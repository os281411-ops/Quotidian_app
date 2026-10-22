import Combine
import Foundation
import Supabase

/// Loads and changes book clubs: the ones you're in, the public ones to
/// discover, and joining, leaving, creating and deleting.
///
/// Every rule (who can see a private club, who can delete one) is enforced
/// by the database; this just asks and reports back.
@MainActor
final class ClubStore: ObservableObject {
    @Published private(set) var myClubs: [BookClub] = []
    @Published private(set) var discoverClubs: [BookClub] = []
    /// Your role in each club you belong to, keyed by club ID.
    @Published private(set) var myRoles: [UUID: ClubMember.Role] = [:]
    @Published private(set) var isLoadingMine = false
    @Published private(set) var isLoadingDiscover = false
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    private var lastSearch = ""

    func role(in club: BookClub) -> ClubMember.Role? { myRoles[club.id] }

    /// Forget everything, e.g. after signing out.
    func reset() {
        myClubs = []
        discoverClubs = []
        myRoles = [:]
        errorMessage = nil
    }

    // MARK: - Loading

    func refreshMine(userID: UUID) async {
        isLoadingMine = true
        defer { isLoadingMine = false }

        do {
            let memberships: [MembershipRow] = try await supabase
                .from("club_members")
                .select("club_id, role")
                .eq("user_id", value: userID)
                .execute()
                .value

            myRoles = Dictionary(uniqueKeysWithValues: memberships.map { ($0.clubID, $0.role) })

            guard !memberships.isEmpty else {
                myClubs = []
                return
            }

            myClubs = try await supabase
                .from("book_clubs")
                .select(BookClub.columns)
                .in("id", values: memberships.map(\.clubID))
                .order("name")
                .execute()
                .value
        } catch {
            errorMessage = "Couldn't load your clubs. Pull down to try again."
        }
    }

    func refreshDiscover(search: String = "") async {
        lastSearch = search
        isLoadingDiscover = true
        defer { isLoadingDiscover = false }

        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            var request = supabase
                .from("book_clubs")
                .select(BookClub.columns)
                .eq("is_private", value: false)
            if !query.isEmpty {
                request = request.ilike("name", pattern: "%\(query)%")
            }
            let results: [BookClub] = try await request
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            // A newer search may have started while this one was in flight.
            guard search == lastSearch else { return }
            discoverClubs = results
        } catch {
            errorMessage = "Couldn't load clubs. Pull down to try again."
        }
    }

    func fetchClub(id: UUID) async -> BookClub? {
        try? await supabase
            .from("book_clubs")
            .select(BookClub.columns)
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func fetchMembers(clubID: UUID) async -> [ClubMember] {
        let members: [ClubMember]? = try? await supabase
            .from("club_members")
            .select(ClubMember.columns)
            .eq("club_id", value: clubID)
            .order("joined_at")
            .execute()
            .value
        // Owner first, then moderators, then everyone else by join date.
        return (members ?? []).sorted { lhs, rhs in
            let order: [ClubMember.Role] = [.owner, .moderator, .member]
            let l = order.firstIndex(of: lhs.role)!, r = order.firstIndex(of: rhs.role)!
            return l == r ? lhs.joinedAt < rhs.joinedAt : l < r
        }
    }

    // MARK: - Changes

    @discardableResult
    func join(_ club: BookClub, userID: UUID) async -> Bool {
        await perform(failure: "Couldn't join this club. Please try again.") {
            _ = try await supabase
                .from("club_members")
                .insert(NewMembership(clubID: club.id, userID: userID))
                .execute()
        } then: {
            await self.refreshAfterChange(userID: userID)
        }
    }

    @discardableResult
    func leave(_ club: BookClub, userID: UUID) async -> Bool {
        await perform(failure: "Couldn't leave this club. Please try again.") {
            _ = try await supabase
                .from("club_members")
                .delete()
                .eq("club_id", value: club.id)
                .eq("user_id", value: userID)
                .execute()
        } then: {
            await self.refreshAfterChange(userID: userID)
        }
    }

    /// Returns the new club, or nil (with `errorMessage` set) if it couldn't be created.
    func create(name: String, description: String, isPrivate: Bool, userID: UUID) async -> BookClub? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard BookClub.nameLimit.contains(trimmedName.count) else {
            errorMessage = "Club names need 3–60 characters."
            return nil
        }

        var created: BookClub?
        await perform(failure: "Couldn't create the club. Please try again.") {
            created = try await supabase
                .from("book_clubs")
                .insert(
                    NewBookClub(
                        name: trimmedName,
                        description: trimmedDescription.isEmpty ? nil : String(trimmedDescription.prefix(BookClub.descriptionLimit)),
                        isPrivate: isPrivate,
                        ownerID: userID
                    ),
                    returning: .representation
                )
                .select(BookClub.columns)
                .single()
                .execute()
                .value
        } then: {
            await self.refreshAfterChange(userID: userID)
        }
        // Re-read from your clubs so the member count includes you.
        return created.flatMap { new in myClubs.first { $0.id == new.id } ?? new }
    }

    @discardableResult
    func delete(_ club: BookClub, userID: UUID) async -> Bool {
        await perform(failure: "Couldn't delete this club. Please try again.") {
            _ = try await supabase
                .from("book_clubs")
                .delete()
                .eq("id", value: club.id)
                .execute()
        } then: {
            await self.refreshAfterChange(userID: userID)
        }
    }

    // MARK: - Invites

    /// What an invite code points at, shown before joining.
    func previewInvite(_ code: String) async -> InvitePreview? {
        errorMessage = nil
        do {
            let matches: [InvitePreview] = try await supabase
                .rpc("preview_invite", params: ["p_code": code])
                .execute()
                .value
            if matches.isEmpty {
                errorMessage = "That code doesn't match a club. Check it and try again."
            }
            return matches.first
        } catch {
            errorMessage = "Couldn't check that code. Check your connection."
            return nil
        }
    }

    /// Joins the club behind an invite code (works for private clubs too).
    func joinWithInvite(_ code: String, userID: UUID) async -> BookClub? {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            let clubID: UUID = try await supabase
                .rpc("join_with_invite", params: ["p_code": code])
                .execute()
                .value
            await refreshAfterChange(userID: userID)
            if let club = myClubs.first(where: { $0.id == clubID }) {
                return club
            }
            return await fetchClub(id: clubID)
        } catch let error as PostgrestError {
            errorMessage = error.hint == "bad_code"
                ? "That code doesn't match a club. Check it and try again."
                : (error.code == "42501" ? "This account can't join clubs." : "Couldn't join. Please try again.")
            return nil
        } catch {
            errorMessage = "Couldn't join. Check your connection and try again."
            return nil
        }
    }

    /// The club's invite code (owners and moderators only).
    func inviteCode(for club: BookClub) async -> String? {
        let code: String? = try? await supabase
            .rpc("club_invite_code", params: ["p_club_id": club.id.uuidString])
            .execute()
            .value
        return code
    }

    /// Replaces the club's invite code; the old one stops working.
    func regenerateInviteCode(for club: BookClub) async -> String? {
        let code: String? = try? await supabase
            .rpc("regenerate_invite_code", params: ["p_club_id": club.id.uuidString])
            .execute()
            .value
        return code
    }

    // MARK: - Helpers

    private func refreshAfterChange(userID: UUID) async {
        await refreshMine(userID: userID)
        await refreshDiscover(search: lastSearch)
    }

    /// Runs a change, maps database errors to readable messages, then refreshes.
    @discardableResult
    private func perform(
        failure: String,
        _ change: () async throws -> Void,
        then refresh: () async -> Void
    ) async -> Bool {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            try await change()
        } catch let error as PostgrestError {
            errorMessage = Self.message(for: error) ?? failure
            return false
        } catch {
            errorMessage = failure
            return false
        }
        await refresh()
        return true
    }

    private static func message(for error: PostgrestError) -> String? {
        switch (error.code ?? "", error.hint ?? "") {
        case (_, "word_filter"): return "That contains language that isn't allowed in Bookclub."
        case (_, "rate_limit"):  return "You're going a bit fast. Wait a minute and try again."
        case ("23505", _):       return "You're already in this club."
        case ("23514", _):       return "Club names need 3–60 characters, and descriptions up to 500."
        case ("42501", _):       return "You don't have permission to do that."
        default:                 return nil
        }
    }
}

/// Result of `preview_invite`: the club an invite code points at.
nonisolated struct InvitePreview: Decodable, Identifiable, Sendable {
    let clubID: UUID
    let name: String
    let isPrivate: Bool
    let memberCount: Int
    let alreadyMember: Bool

    var id: UUID { clubID }

    enum CodingKeys: String, CodingKey {
        case clubID = "club_id"
        case name
        case isPrivate = "is_private"
        case memberCount = "member_count"
        case alreadyMember = "already_member"
    }

    /// Invite codes are 8 letters/numbers; tidy whatever was typed or pasted.
    static func normalize(_ input: String) -> String {
        String(input.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(8))
    }
}

import Combine
import Foundation
import Supabase

/// Someone you've blocked, with their public profile.
nonisolated struct BlockedReader: Decodable, Hashable, Identifiable, Sendable {
    let blockedID: UUID
    let createdAt: Date
    let profile: MemberProfile?

    var id: UUID { blockedID }

    var name: String {
        profile?.displayName ?? profile?.username.map { "@\($0)" } ?? "Reader"
    }

    enum CodingKeys: String, CodingKey {
        case blockedID = "blocked_id"
        case createdAt = "created_at"
        case profile
    }

    // `blocks` has two links to profiles (blocker and blocked), so name the one we want.
    static let columns =
        "blocked_id, created_at, profile:profiles!blocks_blocked_id_fkey(username, display_name)"
}

private nonisolated struct NewBlock: Encodable, Sendable {
    let blockerID: UUID
    let blockedID: UUID

    enum CodingKeys: String, CodingKey {
        case blockerID = "blocker_id"
        case blockedID = "blocked_id"
    }
}

private nonisolated struct NewUserReport: Encodable, Sendable {
    let reporterID: UUID
    let reportedUserID: UUID
    let reason: String

    enum CodingKeys: String, CodingKey {
        case reporterID = "reporter_id"
        case reportedUserID = "reported_user_id"
        case reason
    }
}

/// Blocking and reporting people. Blocking is enforced by the database:
/// a blocked person's messages simply stop coming back for you.
@MainActor
final class SafetyStore: ObservableObject {
    @Published private(set) var blocked: [BlockedReader] = []
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    func isBlocked(_ userID: UUID) -> Bool {
        blocked.contains { $0.blockedID == userID }
    }

    func reset() {
        blocked = []
        errorMessage = nil
    }

    func load() async {
        do {
            blocked = try await supabase
                .from("blocks")
                .select(BlockedReader.columns)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            errorMessage = "Couldn't load your blocked list."
        }
    }

    @discardableResult
    func block(_ userID: UUID, me: UUID) async -> Bool {
        guard userID != me else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await supabase
                .from("blocks")
                .insert(NewBlock(blockerID: me, blockedID: userID))
                .execute()
            await load()
            return true
        } catch {
            if isBlocked(userID) { return true }   // already blocked
            errorMessage = "Couldn't block. Please try again."
            return false
        }
    }

    @discardableResult
    func unblock(_ userID: UUID, me: UUID) async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await supabase
                .from("blocks")
                .delete()
                .eq("blocker_id", value: me)
                .eq("blocked_id", value: userID)
                .execute()
            blocked.removeAll { $0.blockedID == userID }
            return true
        } catch {
            errorMessage = "Couldn't unblock. Please try again."
            return false
        }
    }

    /// Report a person (rather than one message).
    @discardableResult
    func report(_ userID: UUID, reason: ReportReason, me: UUID) async -> Bool {
        do {
            _ = try await supabase
                .from("reports")
                .insert(NewUserReport(reporterID: me, reportedUserID: userID, reason: reason.rawValue))
                .execute()
            return true
        } catch {
            errorMessage = "Couldn't send your report. Please try again."
            return false
        }
    }
}

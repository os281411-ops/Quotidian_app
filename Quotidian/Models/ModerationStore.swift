import Combine
import Foundation
import Supabase

/// One open report, with the reported message embedded.
nonisolated struct ReportRow: Decodable, Sendable {
    let id: UUID
    let reason: String
    let createdAt: Date
    let message: ReportedMessage?

    enum CodingKeys: String, CodingKey {
        case id, reason, message
        case createdAt = "created_at"
    }

    static let columns =
        "id, reason, created_at, " +
        "message:messages(id, body, quote_text, is_hidden, created_at, " +
        "club:book_clubs(name), author:profiles(username, display_name), book:books(\(Book.columns)))"
}

nonisolated struct ReportedMessage: Decodable, Hashable, Sendable {
    let id: UUID
    let body: String?
    let quoteText: String?
    let isHidden: Bool
    let createdAt: Date
    let club: ClubName?
    let author: MemberProfile?
    let book: Book?

    enum CodingKeys: String, CodingKey {
        case id, body, club, author, book
        case quoteText = "quote_text"
        case isHidden = "is_hidden"
        case createdAt = "created_at"
    }
}

nonisolated struct ClubName: Decodable, Hashable, Sendable {
    let name: String
}

/// One open report about a person (not a message).
nonisolated struct UserReportRow: Decodable, Sendable {
    let id: UUID
    let reason: String
    let createdAt: Date
    let reportedUserID: UUID
    let reported: MemberProfile?

    enum CodingKeys: String, CodingKey {
        case id, reason, reported
        case createdAt = "created_at"
        case reportedUserID = "reported_user_id"
    }

    // `reports` links to profiles twice (reporter and reported), so name the one we want.
    static let columns =
        "id, reason, created_at, reported_user_id, " +
        "reported:profiles!reports_reported_user_id_fkey(username, display_name)"
}

/// A reported person with every open report against them.
struct ReportedPerson: Identifiable {
    let userID: UUID
    let profile: MemberProfile?
    let reports: [UserReportRow]

    var id: UUID { userID }
    var name: String { profile?.displayName ?? profile?.username.map { "@\($0)" } ?? "Reader" }
    var latestReport: Date { reports.map(\.createdAt).max() ?? .distantPast }
    var reasonSummary: String { summarizeReasons(reports.map(\.reason)) }
}

/// e.g. "Harassment ×2, Spam"
func summarizeReasons(_ reasons: [String]) -> String {
    Dictionary(grouping: reasons, by: { $0 }).mapValues(\.count)
        .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        .map { reason, count in
            let label = ReportReason(rawValue: reason)?.label ?? reason.capitalized
            return count > 1 ? "\(label) ×\(count)" : label
        }
        .joined(separator: ", ")
}

/// A reported message with every open report against it.
struct ReportedItem: Identifiable {
    let message: ReportedMessage
    let reports: [ReportRow]

    var id: UUID { message.id }
    var latestReport: Date { reports.map(\.createdAt).max() ?? message.createdAt }

    var reasonSummary: String { summarizeReasons(reports.map(\.reason)) }
}

/// Loads open reports and applies moderation decisions. Only works for
/// admins: for anyone else the database returns nothing and refuses actions.
@MainActor
final class ModerationStore: ObservableObject {
    enum Decision: String {
        case remove   // keep the message hidden, mark reports actioned
        case keep     // un-hide the message, dismiss the reports
        case removeAndBan = "remove_and_ban"   // hide it and ban its author
    }

    enum PersonDecision: String {
        case dismiss  // close the reports, no action
        case ban      // ban them and hide everything they've posted
    }

    @Published private(set) var items: [ReportedItem] = []
    @Published private(set) var people: [ReportedPerson] = []
    @Published private(set) var isLoading = false
    @Published private(set) var workingOn: UUID?
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let rows: [ReportRow] = try await supabase
                .from("reports")
                .select(ReportRow.columns)
                .eq("status", value: "open")
                .not("message_id", operator: .`is`, value: "null")
                .order("created_at", ascending: false)
                .limit(500)
                .execute()
                .value

            let grouped = Dictionary(grouping: rows.filter { $0.message != nil }, by: { $0.message!.id })
            items = grouped.values
                .map { ReportedItem(message: $0[0].message!, reports: $0) }
                .sorted { $0.latestReport > $1.latestReport }

            let personRows: [UserReportRow] = try await supabase
                .from("reports")
                .select(UserReportRow.columns)
                .eq("status", value: "open")
                .not("reported_user_id", operator: .`is`, value: "null")
                .order("created_at", ascending: false)
                .limit(500)
                .execute()
                .value
            people = Dictionary(grouping: personRows, by: \.reportedUserID).values
                .map { ReportedPerson(userID: $0[0].reportedUserID, profile: $0[0].reported, reports: $0) }
                .sorted { $0.latestReport > $1.latestReport }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load reports. Pull down to try again."
        }
    }

    func decide(_ decision: Decision, on item: ReportedItem) async {
        workingOn = item.id
        defer { workingOn = nil }

        do {
            _ = try await supabase
                .rpc("moderate_message", params: [
                    "p_message_id": item.message.id.uuidString,
                    "p_action": decision.rawValue,
                ])
                .execute()
            if decision == .removeAndBan {
                await load()   // a ban also closes their other reports
            } else {
                items.removeAll { $0.id == item.id }
            }
        } catch {
            errorMessage = "Couldn't save that decision. Please try again."
        }
    }

    func decide(_ decision: PersonDecision, on person: ReportedPerson) async {
        workingOn = person.id
        defer { workingOn = nil }

        do {
            _ = try await supabase
                .rpc("moderate_user", params: [
                    "p_user_id": person.userID.uuidString,
                    "p_action": decision.rawValue,
                ])
                .execute()
            if decision == .ban {
                await load()
            } else {
                people.removeAll { $0.id == person.id }
            }
        } catch {
            errorMessage = "Couldn't save that decision. Please try again."
        }
    }
}

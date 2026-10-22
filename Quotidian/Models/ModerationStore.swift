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

/// A reported message with every open report against it.
struct ReportedItem: Identifiable {
    let message: ReportedMessage
    let reports: [ReportRow]

    var id: UUID { message.id }
    var latestReport: Date { reports.map(\.createdAt).max() ?? message.createdAt }

    /// e.g. "Harassment ×2, Spam"
    var reasonSummary: String {
        let counts = Dictionary(grouping: reports, by: \.reason).mapValues(\.count)
        return counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { reason, count in
                let label = ReportReason(rawValue: reason)?.label ?? reason.capitalized
                return count > 1 ? "\(label) ×\(count)" : label
            }
            .joined(separator: ", ")
    }
}

/// Loads open reports and applies moderation decisions. Only works for
/// admins: for anyone else the database returns nothing and refuses actions.
@MainActor
final class ModerationStore: ObservableObject {
    enum Decision: String {
        case remove   // keep the message hidden, mark reports actioned
        case keep     // un-hide the message, dismiss the reports
    }

    @Published private(set) var items: [ReportedItem] = []
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
            items.removeAll { $0.id == item.id }
        } catch {
            errorMessage = "Couldn't save that decision. Please try again."
        }
    }
}

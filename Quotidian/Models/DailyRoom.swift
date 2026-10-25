import Combine
import Foundation

/// The shared "Quote of the Day" room: one public club that everyone talks
/// in, with a fresh conversation each day (messages carry the day they're
/// about). The club is created by the database with this fixed ID.
enum DailyRoom {
    static let clubID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!

    /// Stand-in club so the chat screen can open straight away.
    static let club = BookClub(
        id: clubID,
        name: "Quote of the Day",
        description: "One conversation a day about the day's quote.",
        isPrivate: false,
        ownerID: nil,
        createdAt: Date(timeIntervalSince1970: 0)
    )

    /// Today's date as the database stores it ("yyyy-MM-dd", your time zone),
    /// matching the quote Today shows.
    static func today(_ date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// Which tab is showing, plus requests to jump somewhere from another tab
/// (e.g. "Discuss today's quote" on Today opens the room in Bookclub).
@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .today
    /// Set to ask the Bookclub tab to open the daily room once it's ready.
    @Published var wantsDailyRoom = false

    func discussToday() {
        wantsDailyRoom = true
        selectedTab = .community
    }
}

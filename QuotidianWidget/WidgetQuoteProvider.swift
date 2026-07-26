import Foundation

/// Self-contained copy of the quote model/lookup for the widget extension's
/// own bundle — kept independent of the main app target so the two targets
/// don't need to share source files across the project's synced groups.
struct WidgetQuote: Decodable {
    let id: String
    let text: String
    let author: String
    let book: String

    /// False for quotes that aren't drawn from a specific book — kept out of
    /// "today's quote" rotation, mirroring Quote.hasBook in the main app.
    var hasBook: Bool { !book.isEmpty }
}

enum WidgetQuoteProvider {
    static let quotes: [WidgetQuote] = {
        guard let url = Bundle.main.url(forResource: "quotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([WidgetQuote].self, from: data) else {
            return []
        }
        return decoded
    }()

    private static let dailyEligibleQuotes: [WidgetQuote] = quotes.filter(\.hasBook)

    /// Mirrors QuoteProvider.quote(for:) in the main app so the widget and
    /// the app always agree on "today's quote."
    static func quote(for date: Date = Date(), calendar: Calendar = .current) -> WidgetQuote? {
        guard !dailyEligibleQuotes.isEmpty else { return nil }
        let reference = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)) ?? date
        let startOfToday = calendar.startOfDay(for: date)
        let daysSinceReference = calendar.dateComponents([.day], from: reference, to: startOfToday).day ?? 0
        let index = ((daysSinceReference % dailyEligibleQuotes.count) + dailyEligibleQuotes.count) % dailyEligibleQuotes.count
        return dailyEligibleQuotes[index]
    }
}

import Foundation

final class QuoteProvider {
    static let shared = QuoteProvider()

    let quotes: [Quote]

    /// Every quote is in the daily rotation (book quotes and standalone ones).
    /// quotes.json is ordered so book quotes are spread evenly through the
    /// cycle: there are never more than two days in a row without a book.
    /// The widget uses the same file and logic (WidgetQuoteProvider).
    private let dailyEligibleQuotes: [Quote]

    private init() {
        guard let url = Bundle.main.url(forResource: "quotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Quote].self, from: data) else {
            quotes = []
            dailyEligibleQuotes = []
            return
        }
        quotes = decoded
        dailyEligibleQuotes = decoded
    }

    /// Deterministic "quote of the day" — every user sees the same quote on the
    /// same calendar day, and the set cycles forward once it's exhausted.
    func quote(for date: Date = Date(), calendar: Calendar = .current) -> Quote? {
        guard !dailyEligibleQuotes.isEmpty else { return nil }
        let reference = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)) ?? date
        let startOfToday = calendar.startOfDay(for: date)
        let daysSinceReference = calendar.dateComponents([.day], from: reference, to: startOfToday).day ?? 0
        let index = ((daysSinceReference % dailyEligibleQuotes.count) + dailyEligibleQuotes.count) % dailyEligibleQuotes.count
        return dailyEligibleQuotes[index]
    }
}

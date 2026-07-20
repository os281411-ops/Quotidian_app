import Foundation

final class QuoteProvider {
    static let shared = QuoteProvider()

    let quotes: [Quote]

    private init() {
        guard let url = Bundle.main.url(forResource: "quotes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Quote].self, from: data) else {
            quotes = []
            return
        }
        quotes = decoded
    }

    /// Deterministic "quote of the day" — every user sees the same quote on the
    /// same calendar day, and the set cycles forward once it's exhausted.
    func quote(for date: Date = Date(), calendar: Calendar = .current) -> Quote? {
        guard !quotes.isEmpty else { return nil }
        let reference = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)) ?? date
        let startOfToday = calendar.startOfDay(for: date)
        let daysSinceReference = calendar.dateComponents([.day], from: reference, to: startOfToday).day ?? 0
        let index = ((daysSinceReference % quotes.count) + quotes.count) % quotes.count
        return quotes[index]
    }
}

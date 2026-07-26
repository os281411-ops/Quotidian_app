import Foundation

/// Self-contained copy of the quote model/lookup for the widget extension's
/// own bundle — kept independent of the main app target so the two targets
/// don't need to share source files across the project's synced groups.
struct WidgetQuote: Decodable {
    let id: String
    let text: String
    let author: String
    let book: String
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

    /// Mirrors QuoteProvider.quote(for:) in the main app so the widget and
    /// the app always agree on "today's quote."
    static func quote(for date: Date = Date(), calendar: Calendar = .current) -> WidgetQuote? {
        guard !quotes.isEmpty else { return nil }
        let reference = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)) ?? date
        let startOfToday = calendar.startOfDay(for: date)
        let daysSinceReference = calendar.dateComponents([.day], from: reference, to: startOfToday).day ?? 0
        let index = ((daysSinceReference % quotes.count) + quotes.count) % quotes.count
        return quotes[index]
    }
}

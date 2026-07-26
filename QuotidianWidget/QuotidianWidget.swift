import SwiftUI
import WidgetKit

struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: WidgetQuote?
    let isSubscribed: Bool
}

struct QuoteTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: Date(), quote: WidgetQuoteProvider.quote(), isSubscribed: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuoteEntry) -> Void) {
        if context.isPreview {
            completion(QuoteEntry(date: Date(), quote: WidgetQuoteProvider.quote(), isSubscribed: true))
            return
        }
        Task {
            let subscribed = await WidgetEntitlement.isSubscribed()
            completion(QuoteEntry(date: Date(), quote: WidgetQuoteProvider.quote(), isSubscribed: subscribed))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteEntry>) -> Void) {
        Task {
            let subscribed = await WidgetEntitlement.isSubscribed()
            let now = Date()
            let calendar = Calendar.current
            let entry = QuoteEntry(date: now, quote: WidgetQuoteProvider.quote(for: now), isSubscribed: subscribed)
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
                ?? now.addingTimeInterval(86_400)
            completion(Timeline(entries: [entry], policy: .after(startOfTomorrow)))
        }
    }
}

struct QuotidianWidgetEntryView: View {
    var entry: QuoteEntry
    @Environment(\.widgetFamily) private var family

    private static let accent = Color(red: 0.847, green: 0.663, blue: 0.298)

    var body: some View {
        Group {
            if !entry.isSubscribed {
                lockedView
            } else if let quote = entry.quote {
                quoteView(quote)
            } else {
                Text("Quotidian")
                    .foregroundStyle(.white)
            }
        }
        .containerBackground(.black, for: .widget)
    }

    private var lockedView: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
            Text("Unlock with Quotidian Premium")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func quoteView(_ quote: WidgetQuote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\u{201C}\(quote.text)\u{201D}")
                .font(.system(.footnote, design: .serif))
                .italic()
                .foregroundStyle(.white)
                .lineLimit(family == .systemSmall ? 4 : 6)
            Spacer(minLength: 0)
            Text(quote.author)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Self.accent)
        }
        .padding()
    }
}

struct QuotidianWidget: Widget {
    let kind = "QuotidianWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuoteTimelineProvider()) { entry in
            QuotidianWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quotidian")
        .description("Today's quote, right on your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemMedium) {
    QuotidianWidget()
} timeline: {
    QuoteEntry(date: .now, quote: WidgetQuoteProvider.quote(), isSubscribed: true)
    QuoteEntry(date: .now, quote: WidgetQuoteProvider.quote(), isSubscribed: false)
}

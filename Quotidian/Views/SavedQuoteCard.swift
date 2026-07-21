import SwiftUI

struct SavedQuoteCard: View {
    let saved: SavedQuote
    var searchQuery: String = ""
    let onOpenAbout: () -> Void
    let onRemove: () -> Void

    private var quote: Quote { saved.quote }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button(action: onOpenAbout) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("\"\(quote.text)\"".highlighted(matching: searchQuery, baseColor: Theme.textPrimary, highlightColor: Theme.accent))
                        .font(Theme.Font.serif(19).italic())
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(quote.author.highlighted(matching: searchQuery, baseColor: Theme.textPrimary, highlightColor: Theme.accent))
                            .font(Theme.Font.serif(15))
                        Text(quote.book.highlighted(matching: searchQuery, baseColor: Theme.textSecondary, highlightColor: Theme.accent))
                            .font(.caption2.weight(.semibold))
                            .trackedCaps(1.2)
                    }
                }
            }
            .buttonStyle(.plain)

            Divider().overlay(Theme.divider)

            HStack {
                Link(destination: quote.purchaseURL) {
                    HStack(spacing: 6) {
                        Image(systemName: "bag.fill")
                            .font(.caption2)
                        Text("Buy")
                            .font(.caption.weight(.bold))
                            .trackedCaps(1)
                    }
                    .foregroundStyle(Theme.accent)
                }

                Text("·")
                    .foregroundStyle(Theme.textSecondary)

                Text(saved.dateSaved.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption.weight(.medium))
                    .trackedCaps(0.5)
                    .foregroundStyle(Theme.textSecondary)

                Spacer()

                ShareLink(item: quote.shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                Button(action: onRemove) {
                    Image(systemName: "bookmark.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        SavedQuoteCard(
            saved: SavedQuote(quote: QuoteProvider.shared.quote() ?? Quote(id: "x", text: "Preview.", author: "Author", book: "Book", year: "2024", about: "About.", isbn13: nil), dateSaved: Date()),
            onOpenAbout: {},
            onRemove: {}
        )
        .padding()
    }
}

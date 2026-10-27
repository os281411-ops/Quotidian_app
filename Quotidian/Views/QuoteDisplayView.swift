import SwiftUI

struct QuoteDisplayView: View {
    let quote: Quote

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Image(systemName: "quote.opening")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.accent.opacity(0.55))
                Spacer()
            }

            Text(quote.text)
                // Long quotes get slightly smaller type so the page still fits.
                .font(Theme.Font.serif(quote.text.count > 220 ? 21 : quote.text.count > 140 ? 23 : 25).italic())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 6) {
                Text(quote.author)
                    .font(Theme.Font.serif(17))
                    .foregroundStyle(Theme.textPrimary)
                if quote.hasBook {
                    Text(quote.book)
                        .font(.caption.weight(.semibold))
                        .trackedCaps(1.5)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        QuoteDisplayView(quote: QuoteProvider.shared.quote() ?? Quote(id: "x", text: "Preview quote text.", author: "Author", book: "Book", year: "2024", about: "About.", isbn13: nil))
            .padding()
    }
}

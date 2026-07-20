import SwiftUI

struct QuoteDisplayView: View {
    let quote: Quote

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                Image(systemName: "quote.opening")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.accent.opacity(0.55))
                Spacer()
            }

            Text(quote.text)
                .font(Theme.Font.serif(26).italic())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 6) {
                Text(quote.author)
                    .font(Theme.Font.serif(17))
                    .foregroundStyle(Theme.textPrimary)
                Text(quote.book)
                    .font(.caption.weight(.semibold))
                    .trackedCaps(1.5)
                    .foregroundStyle(Theme.textSecondary)
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

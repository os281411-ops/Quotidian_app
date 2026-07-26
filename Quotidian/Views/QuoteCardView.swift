import SwiftUI

/// Fixed-size layout used only for rendering a shareable image (see
/// `QuoteCardRenderer`) — not shown directly in the app's own navigation.
struct QuoteCardView: View {
    let quote: Quote

    var body: some View {
        VStack(spacing: 48) {
            Image(systemName: "quote.opening")
                .font(.system(size: 56))
                .foregroundStyle(Theme.accent.opacity(0.55))

            Text(quote.text)
                .font(Theme.Font.serif(44).italic())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 64)

            VStack(spacing: 10) {
                Text(quote.author)
                    .font(Theme.Font.serif(28))
                    .foregroundStyle(Theme.textPrimary)
                if quote.hasBook {
                    Text(quote.book)
                        .font(.system(size: 15, weight: .semibold))
                        .trackedCaps(2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()

            Text("QUOTIDIAN")
                .font(.system(size: 14, weight: .bold))
                .trackedCaps(3)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 96)
        .padding(.bottom, 56)
        .frame(width: 1080, height: 1080)
        .background(Theme.background)
    }
}

#Preview {
    QuoteCardView(quote: QuoteProvider.shared.quote() ?? Quote(id: "x", text: "Preview quote text.", author: "Author", book: "Book", year: "2024", about: "About.", isbn13: nil))
        .frame(width: 320, height: 320)
        .scaleEffect(320 / 1080)
}

import SwiftUI

/// Fixed-size layout used only for rendering a shareable image (see
/// `QuoteCardRenderer`) — not shown directly in the app's own navigation.
struct QuoteCardView: View {
    let quote: Quote

    var body: some View {
        VStack(spacing: 0) {
            // Invisible copy of the footer, so the quote is centred on the
            // whole card rather than just the space above the footer.
            watermark
                .hidden()

            Spacer(minLength: 32)

            VStack(spacing: 48) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.accent.opacity(0.55))

                Text(quote.text)
                    .font(Theme.Font.serif(44).italic())
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)   // long quotes shrink rather than get cut off
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
            }

            Spacer(minLength: 32)

            watermark
        }
        .padding(.vertical, 56)
        .frame(width: 1080, height: 1080)
        .background(Theme.background)
    }

    /// Branded footer so anyone who sees the image knows where it's from.
    private var watermark: some View {
        VStack(spacing: 22) {
            Rectangle()
                .fill(Theme.accent.opacity(0.35))
                .frame(width: 120, height: 1.5)

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Theme.accent.opacity(0.6), lineWidth: 2)
                        .frame(width: 54, height: 54)
                    Image(systemName: "quote.opening")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quotidian")
                        .font(Theme.Font.serif(30, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("A quote a day from great books · On the App Store")
                        .font(.system(size: 15, weight: .semibold))
                        .trackedCaps(1.5)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }
}

#Preview {
    QuoteCardView(quote: QuoteProvider.shared.quote() ?? Quote(id: "x", text: "Preview quote text.", author: "Author", book: "Book", year: "2024", about: "About.", isbn13: nil))
        .frame(width: 320, height: 320)
        .scaleEffect(320 / 1080)
}

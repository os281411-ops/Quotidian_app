import SwiftUI

struct AboutBookView: View {
    let quote: Quote
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(quote.book)
                        .font(Theme.Font.serif(28, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("\(quote.author) · \(quote.year)")
                        .font(.caption.weight(.semibold))
                        .trackedCaps(1.2)
                        .foregroundStyle(Theme.textSecondary)

                    Divider().overlay(Theme.divider)

                    Text(quote.about)
                        .font(.body)
                        .foregroundStyle(Theme.textPrimary.opacity(0.9))
                        .lineSpacing(4)

                    Divider().overlay(Theme.divider)

                    Text("Featured Quote")
                        .font(.caption.weight(.semibold))
                        .trackedCaps(1.5)
                        .foregroundStyle(Theme.textSecondary)

                    Text("\"\(quote.text)\"")
                        .font(Theme.Font.serif(17).italic())
                        .foregroundStyle(Theme.textPrimary.opacity(0.85))

                    PurchaseButton(url: quote.purchaseURL, title: "Get this book on Bookshop.org")
                        .padding(.top, 8)
                }
                .padding(24)
            }
            .background(Theme.background)
            .navigationTitle("About the Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationBackground(Theme.background)
    }
}

#Preview {
    AboutBookView(quote: QuoteProvider.shared.quote() ?? Quote(id: "x", text: "Preview quote text.", author: "Author", book: "Book", year: "2024", about: "About the book goes here.", isbn13: nil))
}

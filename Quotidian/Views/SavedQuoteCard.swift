import SwiftUI

struct SavedQuoteCard: View {
    let saved: SavedQuote
    var searchQuery: String = ""
    let onOpenAbout: () -> Void
    let onRemove: () -> Void
    /// Opens "Share to a Club" for this quote.
    var onShareToClub: (() -> Void)? = nil

    @EnvironmentObject private var reflections: ReflectionStore
    @State private var editingThought = false

    private var quote: Quote { saved.quote }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button(action: { if quote.hasBook { onOpenAbout() } }) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("\"\(quote.text)\"".highlighted(matching: searchQuery, baseColor: Theme.textPrimary, highlightColor: Theme.accent))
                        .font(Theme.Font.serif(19).italic())
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(quote.author.highlighted(matching: searchQuery, baseColor: Theme.textPrimary, highlightColor: Theme.accent))
                            .font(Theme.Font.serif(15))
                        if quote.hasBook {
                            Text(quote.book.highlighted(matching: searchQuery, baseColor: Theme.textSecondary, highlightColor: Theme.accent))
                                .font(.caption2.weight(.semibold))
                                .trackedCaps(1.2)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            if let reflection = reflections.reflection(for: quote) {
                Button { editingThought = true } label: {
                    reflectionSummary(reflection)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Edit your thought")
            } else {
                Button { editingThought = true } label: {
                    Label("Add a thought", systemImage: "square.and.pencil")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(Theme.divider)

            HStack {
                if quote.hasBook {
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
                }

                Text(saved.dateSaved.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption.weight(.medium))
                    .trackedCaps(0.5)
                    .foregroundStyle(Theme.textSecondary)

                Spacer()

                if let onShareToClub {
                    Button(action: onShareToClub) {
                        Image(systemName: "person.2")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share to a club")
                    .padding(.trailing, 8)
                }

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
        .sheet(isPresented: $editingThought) {
            ReflectionNoteSheet(quote: quote)
        }
    }
}

extension SavedQuoteCard {
    /// Your mood and note from the Reflect card, shown under the quote.
    fileprivate func reflectionSummary(_ reflection: Reflection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let mood = reflection.mood {
                    Label(mood.label, systemImage: mood.selectedSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            let note = reflection.note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !note.isEmpty {
                Text(note)
                    .font(Theme.Font.serif(15).italic())
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surfaceElevated))
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
        .environmentObject(ReflectionStore())
        .padding()
    }
}

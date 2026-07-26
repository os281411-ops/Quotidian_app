import SwiftUI

/// Subscriber-only browse of every quote in the collection — free users only
/// ever see today's single quote on the Today tab.
struct ArchiveView: View {
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var paywall: PaywallPresenter

    @State private var searchText = ""
    @State private var selectedQuote: Quote?
    @FocusState private var isSearchFocused: Bool

    private var filteredQuotes: [Quote] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return QuoteProvider.shared.quotes }
        return QuoteProvider.shared.quotes.filter {
            $0.text.lowercased().contains(query)
                || $0.author.lowercased().contains(query)
                || $0.book.lowercased().contains(query)
        }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if subscriptions.isSubscribed {
                unlockedContent
            } else {
                lockedState
            }
        }
        .sheet(item: $selectedQuote) { quote in
            AboutBookView(quote: quote)
        }
    }

    private var unlockedContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Archive")
                        .font(Theme.Font.serif(34, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(QuoteProvider.shared.quotes.count) Quotes")
                        .font(.caption.weight(.semibold))
                        .trackedCaps(1.5)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

                searchField

                if filteredQuotes.isEmpty {
                    noResultsState
                } else {
                    VStack(spacing: 12) {
                        ForEach(filteredQuotes) { quote in
                            ArchiveQuoteRow(
                                quote: quote,
                                isSaved: library.isSaved(quote),
                                onTap: { if quote.hasBook { selectedQuote = quote } },
                                onToggleSave: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                        library.toggle(quote)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 140)
        }
        .simultaneousGesture(
            TapGesture().onEnded { isSearchFocused = false }
        )
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)

            TextField("Search all quotes", text: $searchText)
                .foregroundStyle(Theme.textPrimary)
                .tint(Theme.accent)
                .autocorrectionDisabled()
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(Theme.textSecondary)
            Text("No Matches")
                .font(Theme.Font.serif(20))
                .foregroundStyle(Theme.textPrimary)
            Text("No quotes contain \"\(searchText)\".")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var lockedState: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
            Text("Browse Every Quote")
                .font(Theme.Font.serif(24, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Premium unlocks the full archive, searchable anytime.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                paywall.present(.archive)
            } label: {
                Text("Unlock Premium")
                    .font(.subheadline.weight(.bold))
                    .trackedCaps(1.5)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Theme.accent))
                    .foregroundStyle(Theme.background)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }
}

private struct ArchiveQuoteRow: View {
    let quote: Quote
    let isSaved: Bool
    let onTap: () -> Void
    let onToggleSave: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\"\(quote.text)\"")
                        .font(Theme.Font.serif(16).italic())
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(quote.hasBook ? "\(quote.author) · \(quote.book)" : quote.author)
                        .font(.caption2.weight(.semibold))
                        .trackedCaps(1)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button(action: onToggleSave) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(isSaved ? Theme.accent : Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.divider, lineWidth: 1))
    }
}

#Preview {
    ArchiveView()
        .environmentObject(LibraryStore())
        .environmentObject(SubscriptionManager())
        .environmentObject(PaywallPresenter())
}

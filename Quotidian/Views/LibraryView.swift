import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var streak: StreakManager
    @State private var selectedQuote: Quote?
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    @State private var pendingRemoval: (saved: SavedQuote, index: Int)?
    @State private var undoWorkItem: DispatchWorkItem?

    private var filteredQuotes: [SavedQuote] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return library.savedQuotes }
        return library.savedQuotes.filter {
            $0.quote.text.lowercased().contains(query)
                || $0.quote.author.lowercased().contains(query)
                || $0.quote.book.lowercased().contains(query)
        }
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Library")
                                .font(Theme.Font.serif(34, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Saved Passages")
                                .font(.caption.weight(.semibold))
                                .trackedCaps(1.5)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        StreakBadgeView(streak: streak.currentStreak, style: .compact)
                            .padding(.top, 4)
                    }
                    .padding(.top, 8)

                    if library.savedQuotes.isEmpty {
                        emptyState
                    } else {
                        searchField

                        if filteredQuotes.isEmpty {
                            noResultsState
                        } else {
                            VStack(spacing: 16) {
                                ForEach(filteredQuotes) { saved in
                                    SavedQuoteCard(
                                        saved: saved,
                                        searchQuery: searchText,
                                        onOpenAbout: { selectedQuote = saved.quote },
                                        onRemove: { removeWithUndo(saved) }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 140)
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    isSearchFocused = false
                }
            )

            if let pendingRemoval {
                VStack {
                    Spacer()
                    UndoToast(message: "Removed from Library") {
                        undo(pendingRemoval)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $selectedQuote) { quote in
            AboutBookView(quote: quote)
        }
    }

    private func removeWithUndo(_ saved: SavedQuote) {
        let index = library.savedQuotes.firstIndex { $0.quote.id == saved.quote.id } ?? 0

        withAnimation(.easeOut(duration: 0.25)) {
            library.remove(saved.quote)
        }

        undoWorkItem?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            pendingRemoval = (saved, index)
        }

        let workItem = DispatchWorkItem {
            withAnimation(.easeOut(duration: 0.3)) {
                pendingRemoval = nil
            }
        }
        undoWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    private func undo(_ pending: (saved: SavedQuote, index: Int)) {
        undoWorkItem?.cancel()
        library.restore(pending.saved, at: pending.index)
        withAnimation(.easeOut(duration: 0.3)) {
            pendingRemoval = nil
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)

            TextField("Search your quotes", text: $searchText)
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textSecondary)
            Text("No Saved Quotes")
                .font(Theme.Font.serif(20))
                .foregroundStyle(Theme.textPrimary)
            Text("Tap the bookmark on the daily quote to save it here.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(Theme.textSecondary)
            Text("No Matches")
                .font(Theme.Font.serif(20))
                .foregroundStyle(Theme.textPrimary)
            Text("No saved quotes contain \"\(searchText)\".")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

#Preview {
    LibraryView()
        .environmentObject(LibraryStore())
        .environmentObject(StreakManager())
}

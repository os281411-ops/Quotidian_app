import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var streak: StreakManager
    @State private var selectedQuote: Quote?

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
                        VStack(spacing: 16) {
                            ForEach(library.savedQuotes) { saved in
                                SavedQuoteCard(
                                    saved: saved,
                                    onOpenAbout: { selectedQuote = saved.quote },
                                    onRemove: {
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            library.remove(saved.quote)
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
        }
        .sheet(item: $selectedQuote) { quote in
            AboutBookView(quote: quote)
        }
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
}

#Preview {
    LibraryView()
        .environmentObject(LibraryStore())
        .environmentObject(StreakManager())
}

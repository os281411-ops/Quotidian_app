import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var streak: StreakManager

    @State private var quote: Quote?
    @State private var showAbout = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 36) {
                    HStack {
                        Text("Quotidian")
                            .font(.caption.weight(.bold))
                            .trackedCaps(2)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        StreakBadgeView(streak: streak.currentStreak, style: .full)
                    }
                    .padding(.top, 8)

                    if let quote {
                        QuoteDisplayView(quote: quote)

                        PurchaseButton(url: quote.purchaseURL, title: "Purchase Book")

                        HStack(spacing: 40) {
                            ShareLink(item: quote.shareText) {
                                CircleIconButtonLabel(systemImage: "square.and.arrow.up", label: "Share")
                            }

                            CircleIconButton(
                                systemImage: library.isSaved(quote) ? "bookmark.fill" : "bookmark",
                                label: "Save",
                                isActive: library.isSaved(quote)
                            ) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                                    library.toggle(quote)
                                }
                            }

                            CircleIconButton(systemImage: "info.circle", label: "About") {
                                showAbout = true
                            }
                        }
                        .padding(.top, 4)
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 140)
            }
        }
        .sheet(isPresented: $showAbout) {
            if let quote {
                AboutBookView(quote: quote)
            }
        }
        .overlay {
            if streak.showCelebration {
                StreakCelebrationView(
                    streak: streak.currentStreak,
                    milestoneLabel: StreakMilestone.label(for: streak.currentStreak)
                ) {
                    streak.dismissCelebration()
                }
            }
        }
        .onAppear {
            if quote == nil {
                quote = QuoteProvider.shared.quote()
            }
            streak.registerVisitIfNeeded()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textSecondary)
            Text("No Quote Today")
                .font(Theme.Font.serif(20))
                .foregroundStyle(Theme.textPrimary)
            Text("Check back tomorrow for a new quote.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 80)
    }
}

#Preview {
    TodayView()
        .environmentObject(LibraryStore())
        .environmentObject(StreakManager())
}

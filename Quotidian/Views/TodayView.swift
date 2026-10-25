import SwiftUI
import UIKit

struct TodayView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var streak: StreakManager
    @EnvironmentObject private var subscriptions: SubscriptionManager
    @EnvironmentObject private var paywall: PaywallPresenter
    @EnvironmentObject private var router: AppRouter

    @State private var quote: Quote?
    @State private var showAbout = false
    @State private var shareCardImage: UIImage?
    @State private var showShareToClub = false

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

                        if quote.hasBook {
                            PurchaseButton(url: quote.purchaseURL, title: "Purchase Book")
                        }

                        // Three buttons so Save stays in the centre: sharing options
                        // live in the Share menu, and About keeps its space when absent.
                        HStack(spacing: 40) {
                            shareMenu(for: quote)

                            CircleIconButton(
                                systemImage: library.isSaved(quote) ? "bookmark.fill" : "bookmark",
                                label: "Save",
                                isActive: library.isSaved(quote),
                                isEmphasized: true
                            ) {
                                toggleSave(quote)
                            }

                            // Book quotes: About here, Reflect below Save.
                            // Book-less quotes: Reflect takes About's place.
                            if quote.hasBook {
                                CircleIconButton(systemImage: "info.circle", label: "About") {
                                    showAbout = true
                                }
                            } else {
                                ReflectButton(quote: quote)
                            }
                        }
                        .padding(.top, 64)

                        if quote.hasBook {
                            ReflectButton(quote: quote)
                                .padding(.top, -12)
                        }

                        discussButton
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
        .sheet(isPresented: $showShareToClub) {
            if let quote {
                ShareToClubView(quote: quote)
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
            streak.registerVisitIfNeeded(isSubscribed: subscriptions.isSubscribed)
        }
        .task(id: shareCardTaskID) {
            guard subscriptions.isSubscribed, let quote else {
                shareCardImage = nil
                return
            }
            shareCardImage = QuoteCardRenderer.render(quote)
        }
    }

    private var shareCardTaskID: String {
        "\(quote?.id ?? "")-\(subscriptions.isSubscribed)"
    }

    @ViewBuilder
    /// Share button: a menu with the system share sheet and Share to a Club.
    private func shareMenu(for quote: Quote) -> some View {
        Menu {
            shareLink(for: quote)
            Button {
                showShareToClub = true
            } label: {
                Label("Share to a Club", systemImage: "person.2")
            }
        } label: {
            CircleIconButtonLabel(systemImage: "square.and.arrow.up", label: "Share")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func shareLink(for quote: Quote) -> some View {
        if let shareCardImage {
            // The card image carries a Quotidian footer; apps that accept a
            // message alongside the image also get the attribution and link.
            ShareLink(
                item: ShareableQuoteImage(image: shareCardImage),
                message: Text(AppLinks.shareAttribution),
                preview: SharePreview(quote.shareLine, image: Image(uiImage: shareCardImage))
            ) {
                Label("Share Quote…", systemImage: "square.and.arrow.up")
            }
        } else {
            ShareLink(item: quote.shareText) {
                Label("Share Quote…", systemImage: "square.and.arrow.up")
            }
        }
    }

    /// Opens today's shared discussion in the Bookclub tab.
    private var discussButton: some View {
        Button {
            router.discussToday()
        } label: {
            Label("Discuss today's quote", systemImage: "bubble.left.and.bubble.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().stroke(Theme.accent.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func toggleSave(_ quote: Quote) {
        if library.isSaved(quote) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                library.toggle(quote)
            }
        } else if subscriptions.isSubscribed || library.savedQuotes.count < LibraryStore.freeSaveLimit {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                library.toggle(quote)
            }
        } else {
            paywall.present(.saveLimit)
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
        .environmentObject(SubscriptionManager())
        .environmentObject(PaywallPresenter())
        .environmentObject(AppRouter())
}

import Combine
import Foundation

/// Where the paywall was triggered from — drives the headline/message so the
/// pitch matches whatever the user just bumped into.
enum PaywallTrigger: Identifiable {
    case onboarding
    case saveLimit
    case shareCard
    case streakFreeze
    case themes
    case secondReminder
    case bookclub
    case general

    var id: Self { self }

    var headline: String {
        switch self {
        case .onboarding: "Welcome to Quotidian"
        case .saveLimit: "You've saved 10 quotes"
        case .shareCard: "Share a Beautiful Card"
        case .streakFreeze: "Never Lose Your Streak"
        case .themes: "Make It Yours"
        case .secondReminder: "A Second Nudge"
        case .bookclub: "Read Together with Premium"
        case .general: "Quotidian Premium"
        }
    }

    var message: String {
        switch self {
        case .onboarding: "Start with Premium for your own book clubs, unlimited saves, and more — or continue with the free daily quote."
        case .saveLimit: "Upgrade to Premium for unlimited saves in your Library."
        case .shareCard: "Premium turns your favorite lines into shareable cards."
        case .streakFreeze: "Premium gives you a monthly streak freeze so a missed day doesn't cost you."
        case .themes: "Premium unlocks curated colour themes for the whole app."
        case .secondReminder: "Premium adds a second daily reminder, so today's quote never slips by."
        case .bookclub: "Premium lets you start your own book clubs and join private ones with an invite."
        case .general: "Unlock book clubs, unlimited saves, and more."
        }
    }
}

/// App-wide switch for presenting the paywall from anywhere, without every
/// view needing its own sheet state.
@MainActor
final class PaywallPresenter: ObservableObject {
    @Published var trigger: PaywallTrigger?

    func present(_ trigger: PaywallTrigger) {
        self.trigger = trigger
    }

    func dismiss() {
        trigger = nil
    }
}

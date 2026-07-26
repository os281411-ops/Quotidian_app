import Combine
import Foundation

/// Where the paywall was triggered from — drives the headline/message so the
/// pitch matches whatever the user just bumped into.
enum PaywallTrigger: Identifiable {
    case saveLimit
    case archive
    case shareCard
    case streakFreeze
    case themes
    case secondReminder
    case general

    var id: Self { self }

    var headline: String {
        switch self {
        case .saveLimit: "You've saved 10 quotes"
        case .archive: "Browse Every Quote"
        case .shareCard: "Share a Beautiful Card"
        case .streakFreeze: "Never Lose Your Streak"
        case .themes: "Make It Yours"
        case .secondReminder: "A Second Nudge"
        case .general: "Quotidian Premium"
        }
    }

    var message: String {
        switch self {
        case .saveLimit: "Upgrade to Premium for unlimited saves in your Library."
        case .archive: "Scroll through every quote, past and future, with Premium."
        case .shareCard: "Premium turns your favorite lines into shareable cards."
        case .streakFreeze: "Premium gives you a monthly streak freeze so a missed day doesn't cost you."
        case .themes: "Premium unlocks curated color themes for the whole app."
        case .secondReminder: "Premium adds a second daily reminder, so today's quote never slips by."
        case .general: "Unlock unlimited saves, the full archive, and more."
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

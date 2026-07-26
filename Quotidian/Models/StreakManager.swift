import Combine
import Foundation

@MainActor
final class StreakManager: ObservableObject {
    /// Premium perk: subscribers get this many "skip a day without breaking
    /// the streak" tokens per calendar month.
    static let monthlyFreezeAllowance = 1

    @Published private(set) var currentStreak: Int
    @Published private(set) var longestStreak: Int
    @Published var showCelebration = false
    @Published private(set) var freezesAvailable: Int
    @Published private(set) var usedFreezeOnLastVisit = false

    private let defaults: UserDefaults
    private let lastVisitKey = "streak.lastVisitDate"
    private let currentStreakKey = "streak.current"
    private let longestStreakKey = "streak.longest"
    private let freezeMonthKey = "streak.freeze.month"
    private let freezeCountKey = "streak.freeze.count"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        currentStreak = defaults.integer(forKey: currentStreakKey)
        longestStreak = defaults.integer(forKey: longestStreakKey)
        freezesAvailable = defaults.object(forKey: freezeCountKey) as? Int ?? Self.monthlyFreezeAllowance
    }

    /// Call once per app session. Bumps the streak the first time a new
    /// calendar day is seen and flags the celebration animation. Subscribers
    /// who miss exactly one day spend a monthly freeze token instead of
    /// resetting, as long as they have one available.
    func registerVisitIfNeeded(isSubscribed: Bool, date: Date = Date(), calendar: Calendar = .current) {
        refreshFreezeAllowanceIfNewMonth(date: date, calendar: calendar)
        usedFreezeOnLastVisit = false

        let today = calendar.startOfDay(for: date)

        guard let lastVisit = defaults.object(forKey: lastVisitKey) as? Date else {
            currentStreak = 1
            longestStreak = max(longestStreak, currentStreak)
            persist(today: today)
            showCelebration = true
            return
        }

        let lastVisitDay = calendar.startOfDay(for: lastVisit)
        guard lastVisitDay != today else { return }

        let daysBetween = calendar.dateComponents([.day], from: lastVisitDay, to: today).day ?? 0

        if daysBetween == 1 {
            currentStreak += 1
        } else if daysBetween == 2, isSubscribed, freezesAvailable > 0 {
            freezesAvailable -= 1
            persistFreezeCount()
            usedFreezeOnLastVisit = true
            currentStreak += 1
        } else {
            currentStreak = 1
        }

        longestStreak = max(longestStreak, currentStreak)
        persist(today: today)
        showCelebration = true
    }

    func dismissCelebration() {
        showCelebration = false
    }

    private func refreshFreezeAllowanceIfNewMonth(date: Date, calendar: Calendar) {
        let currentKey = monthKey(for: date, calendar: calendar)
        guard defaults.string(forKey: freezeMonthKey) != currentKey else { return }
        freezesAvailable = Self.monthlyFreezeAllowance
        defaults.set(currentKey, forKey: freezeMonthKey)
        persistFreezeCount()
    }

    private func monthKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    private func persistFreezeCount() {
        defaults.set(freezesAvailable, forKey: freezeCountKey)
    }

    private func persist(today: Date) {
        defaults.set(today, forKey: lastVisitKey)
        defaults.set(currentStreak, forKey: currentStreakKey)
        defaults.set(longestStreak, forKey: longestStreakKey)
    }
}

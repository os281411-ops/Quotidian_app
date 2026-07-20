import Combine
import Foundation

@MainActor
final class StreakManager: ObservableObject {
    @Published private(set) var currentStreak: Int
    @Published private(set) var longestStreak: Int
    @Published var showCelebration = false

    private let defaults: UserDefaults
    private let lastVisitKey = "streak.lastVisitDate"
    private let currentStreakKey = "streak.current"
    private let longestStreakKey = "streak.longest"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        currentStreak = defaults.integer(forKey: currentStreakKey)
        longestStreak = defaults.integer(forKey: longestStreakKey)
    }

    /// Call once per app session. Bumps the streak the first time a new
    /// calendar day is seen and flags the celebration animation.
    func registerVisitIfNeeded(date: Date = Date(), calendar: Calendar = .current) {
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
        currentStreak = (daysBetween == 1) ? currentStreak + 1 : 1
        longestStreak = max(longestStreak, currentStreak)
        persist(today: today)
        showCelebration = true
    }

    func dismissCelebration() {
        showCelebration = false
    }

    private func persist(today: Date) {
        defaults.set(today, forKey: lastVisitKey)
        defaults.set(currentStreak, forKey: currentStreakKey)
        defaults.set(longestStreak, forKey: longestStreakKey)
    }
}

import Foundation

/// Named streak milestones. Beyond the last named step, milestones continue
/// every 365 days indefinitely so the progress indicator always has a target.
enum StreakMilestone {
    private static let steps = [7, 30, 100, 365]

    static func isMilestone(_ streak: Int) -> Bool {
        streak > 0 && (steps.contains(streak) || (streak >= 365 && streak % 365 == 0))
    }

    /// A short celebratory label, only for days that are actually milestones.
    static func label(for streak: Int) -> String? {
        switch streak {
        case 7: return "One Week Streak!"
        case 30: return "One Month Streak!"
        case 100: return "100 Day Streak!"
        default:
            guard streak >= 365, streak % 365 == 0 else { return nil }
            let years = streak / 365
            return years == 1 ? "One Year Streak!" : "\(years) Year Streak!"
        }
    }

    static func previous(for streak: Int) -> Int {
        if streak >= 365 {
            return (streak / 365) * 365
        }
        return steps.last(where: { $0 <= streak }) ?? 0
    }

    static func next(for streak: Int) -> Int {
        if let step = steps.first(where: { $0 > streak }) {
            return step
        }
        return ((streak / 365) + 1) * 365
    }

    /// Fraction (0...1) of progress within the current milestone band.
    static func progress(for streak: Int) -> Double {
        let lower = previous(for: streak)
        let upper = next(for: streak)
        guard upper > lower else { return 1 }
        return Double(streak - lower) / Double(upper - lower)
    }
}

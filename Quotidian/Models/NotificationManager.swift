import Combine
import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    @Published private(set) var isReminderEnabled: Bool
    @Published var reminderTime: Date
    @Published private(set) var permissionDenied = false

    /// Premium perk: a second, evening reminder.
    @Published private(set) var isEveningReminderEnabled: Bool
    @Published var eveningReminderTime: Date

    private let defaults: UserDefaults
    private let enabledKey = "reminder.enabled"
    private let hourKey = "reminder.hour"
    private let minuteKey = "reminder.minute"
    private let requestIdentifier = "daily-quote-reminder"

    private let eveningEnabledKey = "reminder.evening.enabled"
    private let eveningHourKey = "reminder.evening.hour"
    private let eveningMinuteKey = "reminder.evening.minute"
    /// Old single repeating evening reminder (removed when rescheduling).
    private let eveningRequestIdentifier = "evening-quote-reminder"
    /// The evening reminder is now one notification per day, so each day's
    /// message can depend on whether that day's quote has been read.
    private let eveningDayPrefix = "evening-quote-reminder-"
    private let eveningDaysAhead = 21
    private let lastReadDayKey = "reminder.lastReadDay"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isReminderEnabled = defaults.bool(forKey: enabledKey)

        let hour = defaults.object(forKey: hourKey) as? Int ?? 9
        let minute = defaults.object(forKey: minuteKey) as? Int ?? 0
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        reminderTime = Calendar.current.date(from: components) ?? Date()

        isEveningReminderEnabled = defaults.bool(forKey: eveningEnabledKey)
        let eveningHour = defaults.object(forKey: eveningHourKey) as? Int ?? 20
        let eveningMinute = defaults.object(forKey: eveningMinuteKey) as? Int ?? 0
        var eveningComponents = DateComponents()
        eveningComponents.hour = eveningHour
        eveningComponents.minute = eveningMinute
        eveningReminderTime = Calendar.current.date(from: eveningComponents) ?? Date()

        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func setReminderEnabled(_ enabled: Bool) {
        if enabled {
            requestPermissionAndSchedule()
        } else {
            isReminderEnabled = false
            defaults.set(false, forKey: enabledKey)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        }
    }

    func updateReminderTime(_ date: Date) {
        reminderTime = date
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        defaults.set(components.hour, forKey: hourKey)
        defaults.set(components.minute, forKey: minuteKey)
        if isReminderEnabled {
            scheduleNotification()
        }
    }

    /// Caller is responsible for checking subscription status before enabling.
    func setEveningReminderEnabled(_ enabled: Bool) {
        if enabled {
            requestPermissionAndScheduleEvening()
        } else {
            isEveningReminderEnabled = false
            defaults.set(false, forKey: eveningEnabledKey)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: allEveningIdentifiers())
        }
    }

    /// Call when today's quote has been seen: tonight's reminder changes
    /// from "you haven't read it" to a gentler follow-up.
    func markTodayRead() {
        let today = Self.dayKey(Date())
        guard defaults.string(forKey: lastReadDayKey) != today else { return }
        defaults.set(today, forKey: lastReadDayKey)
        if isEveningReminderEnabled {
            scheduleEveningNotification()
        }
    }

    /// Keeps the next few weeks of evening reminders queued. Call when the
    /// app opens (iOS can't repeat a notification whose wording changes).
    func refreshEveningSchedule() {
        if isEveningReminderEnabled {
            scheduleEveningNotification()
        }
    }

    func updateEveningReminderTime(_ date: Date) {
        eveningReminderTime = date
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        defaults.set(components.hour, forKey: eveningHourKey)
        defaults.set(components.minute, forKey: eveningMinuteKey)
        if isEveningReminderEnabled {
            scheduleEveningNotification()
        }
    }

    private func requestPermissionAndSchedule() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            guard let self else { return }
            Task { @MainActor in
                if granted {
                    self.permissionDenied = false
                    self.isReminderEnabled = true
                    self.defaults.set(true, forKey: self.enabledKey)
                    self.scheduleNotification()
                } else {
                    self.permissionDenied = true
                    self.isReminderEnabled = false
                    self.defaults.set(false, forKey: self.enabledKey)
                }
            }
        }
    }

    private func requestPermissionAndScheduleEvening() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            guard let self else { return }
            Task { @MainActor in
                if granted {
                    self.permissionDenied = false
                    self.isEveningReminderEnabled = true
                    self.defaults.set(true, forKey: self.eveningEnabledKey)
                    self.scheduleEveningNotification()
                } else {
                    self.permissionDenied = true
                    self.isEveningReminderEnabled = false
                    self.defaults.set(false, forKey: self.eveningEnabledKey)
                }
            }
        }
    }

    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Quotidian"
        content.body = "Today's quote is ready for you."
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
        center.add(request)
    }

    private func scheduleEveningNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: allEveningIdentifiers())

        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: eveningReminderTime)
        let readToday = defaults.string(forKey: lastReadDayKey) == Self.dayKey(Date())
        let now = Date()

        for offset in 0..<eveningDaysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
                  let fireDate = calendar.date(bySettingHour: time.hour ?? 20, minute: time.minute ?? 0, second: 0, of: day),
                  fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Quotidian"
            // Only today is known to be read; future days start as unread
            // and get updated when the app is opened that day.
            content.body = (offset == 0 && readToday)
                ? Self.alreadyReadMessage(for: day)
                : "You haven't read today's quote yet."
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(
                identifier: eveningDayPrefix + Self.dayKey(day),
                content: content,
                trigger: trigger
            ))
        }
    }

    /// Evening messages for days the quote has already been read.
    private static func alreadyReadMessage(for day: Date) -> String {
        let messages = [
            "Has today's quote stayed with you? Add a thought before the day ends.",
            "See what other readers made of today's quote in Bookclub.",
            "One more look at today's quote before bed?",
            "How did today's quote make you feel? Tap Reflect to note it down.",
        ]
        let index = (Calendar.current.ordinality(of: .day, in: .era, for: day) ?? 0) % messages.count
        return messages[index]
    }

    private func allEveningIdentifiers() -> [String] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let days = (-1...eveningDaysAhead).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        return [eveningRequestIdentifier] + days.map { eveningDayPrefix + Self.dayKey($0) }
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}

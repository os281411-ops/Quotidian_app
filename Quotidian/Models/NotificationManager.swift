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
    private let eveningRequestIdentifier = "evening-quote-reminder"

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
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [eveningRequestIdentifier])
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
        center.removePendingNotificationRequests(withIdentifiers: [eveningRequestIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Quotidian"
        content.body = "You haven't read today's quote yet."
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: eveningReminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: eveningRequestIdentifier, content: content, trigger: trigger)
        center.add(request)
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

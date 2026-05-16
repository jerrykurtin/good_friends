import Foundation
import UserNotifications

enum NotificationScheduler {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    static func scheduleReminder(for friend: Friend) {
        let center = UNUserNotificationCenter.current()
        let identifier = notificationIdentifier(for: friend)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let reminderDate = nextReminderDate(for: friend)
        guard reminderDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Check in with \(friend.name)"
        content.body = friend.city.isEmpty ? "It has been a little while." : "See how things are in \(friend.city)."
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request)
    }

    static func cancelReminder(for friend: Friend) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier(for: friend)])
    }

    private static func nextReminderDate(for friend: Friend) -> Date {
        let startOfDueDay = Calendar.current.startOfDay(for: friend.dueDate)
        return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: startOfDueDay) ?? friend.dueDate
    }

    private static func notificationIdentifier(for friend: Friend) -> String {
        "friend-reminder-\(friend.id.uuidString)"
    }
}

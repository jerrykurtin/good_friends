import Foundation
import UserNotifications

enum NotificationDeliveryMode: String, CaseIterable, Identifiable {
    case none
    case regularCycle
    case whenCheckInIsDue

    var id: Self { self }

    static let storageKey = "notificationDeliveryMode"
    static let defaultValue: Self = .regularCycle

    var title: String {
        switch self {
        case .none: "None"
        case .regularCycle: "Regular cycle"
        case .whenCheckInIsDue: "Every time a check-in is due"
        }
    }

    var description: String {
        switch self {
        case .none: "Good Friends will not send check-in reminders."
        case .regularCycle: "Good Friends will send a reminder on the regular schedule you choose."
        case .whenCheckInIsDue: "Good Friends will schedule reminders for each friend based on their check-in frequency."
        }
    }
}

enum NotificationRegularUnit: String, CaseIterable, Identifiable {
    case day
    case week

    var id: Self { self }

    static let storageKey = "notificationRegularUnit"
    static let defaultValue: Self = .week

    func title(for value: Int) -> String {
        switch self {
        case .day: value == 1 ? "day" : "days"
        case .week: value == 1 ? "week" : "weeks"
        }
    }

    var calendarComponent: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        }
    }
}

enum NotificationScheduler {
    static let regularValueStorageKey = "notificationRegularValue"
    static let regularHourStorageKey = "notificationRegularHour"
    static let regularMinuteStorageKey = "notificationRegularMinute"
    static let dueHourStorageKey = "notificationDueHour"
    static let dueMinuteStorageKey = "notificationDueMinute"
    static let defaultRegularValue = 1
    static let defaultRegularHour = 18
    static let defaultRegularMinute = 0
    static let defaultDueHour = 18
    static let defaultDueMinute = 0

    private static let regularReminderIdentifierPrefix = "regular-check-in-reminder"
    private static let regularReminderCount = 32

    static func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { isGranted, _ in
            completion?(isGranted)
        }
    }

    static func syncReminder(for friend: Friend) {
        switch currentDeliveryMode {
        case .none:
            cancelRegularReminder()
            cancelDueReminder(for: friend)
        case .regularCycle:
            cancelDueReminder(for: friend)
            scheduleRegularReminders()
        case .whenCheckInIsDue:
            cancelRegularReminder()
            scheduleDueReminder(for: friend)
        }
    }

    static func syncReminders(for friends: [Friend]) {
        switch currentDeliveryMode {
        case .none:
            cancelRegularReminder()
            friends.forEach(cancelDueReminder)
        case .regularCycle:
            friends.forEach(cancelDueReminder)
            scheduleRegularReminders()
        case .whenCheckInIsDue:
            cancelRegularReminder()
            friends.forEach(scheduleDueReminder)
        }
    }

    static func cancelReminder(for friend: Friend) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier(for: friend)])
    }

    private static var currentDeliveryMode: NotificationDeliveryMode {
        let rawValue = UserDefaults.standard.string(forKey: NotificationDeliveryMode.storageKey)
        return rawValue.flatMap(NotificationDeliveryMode.init(rawValue:)) ?? NotificationDeliveryMode.defaultValue
    }

    private static var currentRegularUnit: NotificationRegularUnit {
        let rawValue = UserDefaults.standard.string(forKey: NotificationRegularUnit.storageKey)
        return rawValue.flatMap(NotificationRegularUnit.init(rawValue:)) ?? NotificationRegularUnit.defaultValue
    }

    private static var currentRegularValue: Int {
        let value = UserDefaults.standard.integer(forKey: regularValueStorageKey)
        return value > 0 ? value : defaultRegularValue
    }

    private static var currentRegularHour: Int {
        let hour = UserDefaults.standard.object(forKey: regularHourStorageKey) as? Int
        return min(max(hour ?? defaultRegularHour, 0), 23)
    }

    private static var currentRegularMinute: Int {
        let minute = UserDefaults.standard.object(forKey: regularMinuteStorageKey) as? Int
        return min(max(minute ?? defaultRegularMinute, 0), 59)
    }

    private static var currentDueHour: Int {
        let hour = UserDefaults.standard.object(forKey: dueHourStorageKey) as? Int
        return min(max(hour ?? defaultDueHour, 0), 23)
    }

    private static var currentDueMinute: Int {
        let minute = UserDefaults.standard.object(forKey: dueMinuteStorageKey) as? Int
        return min(max(minute ?? defaultDueMinute, 0), 59)
    }

    private static func scheduleDueReminder(for friend: Friend) {
        let center = UNUserNotificationCenter.current()
        let identifier = notificationIdentifier(for: friend)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let reminderDate = nextReminderDate(for: friend)
        guard reminderDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Check in with \(friend.displayName)"
        content.body = friend.city.isEmpty ? "It has been a little while." : "See how things are in \(friend.city)."
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request)
    }

    private static func scheduleRegularReminders() {
        let center = UNUserNotificationCenter.current()
        cancelRegularReminder()

        let dates = upcomingRegularReminderDates()
        for (index, date) in dates.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Check in with your good friends"
            content.body = "Take a minute to see who you want to catch up with."
            content.sound = .default

            let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: regularReminderIdentifier(for: index), content: content, trigger: trigger)
            center.add(request)
        }
    }

    private static func cancelRegularReminder() {
        let identifiers = [regularReminderIdentifierPrefix] + (0..<regularReminderCount).map(regularReminderIdentifier)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func cancelDueReminder(for friend: Friend) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier(for: friend)])
    }

    private static func nextReminderDate(for friend: Friend) -> Date {
        let startOfDueDay = Calendar.current.startOfDay(for: friend.dueDate)
        return Calendar.current.date(bySettingHour: currentDueHour, minute: currentDueMinute, second: 0, of: startOfDueDay) ?? friend.dueDate
    }

    private static func upcomingRegularReminderDates() -> [Date] {
        var dates: [Date] = []
        var nextDate = nextRegularReminderDate(after: .now)
        let calendar = Calendar.current

        while dates.count < regularReminderCount {
            dates.append(nextDate)
            guard let followingDate = calendar.date(byAdding: currentRegularUnit.calendarComponent, value: currentRegularValue, to: nextDate) else {
                break
            }
            nextDate = followingDate
        }

        return dates
    }

    private static func nextRegularReminderDate(after date: Date) -> Date {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: date)
        var nextDate = calendar.date(bySettingHour: currentRegularHour, minute: currentRegularMinute, second: 0, of: startOfToday) ?? date

        if nextDate <= date {
            nextDate = calendar.date(byAdding: currentRegularUnit.calendarComponent, value: currentRegularValue, to: nextDate) ?? nextDate
        }

        return nextDate
    }

    private static func regularReminderIdentifier(for index: Int) -> String {
        "\(regularReminderIdentifierPrefix)-\(index)"
    }

    private static func notificationIdentifier(for friend: Friend) -> String {
        "friend-reminder-\(friend.id.uuidString)"
    }
}

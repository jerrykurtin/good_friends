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

struct NotificationReminderPlan: Equatable {
    let identifier: String
    let date: Date
    let title: String
    let body: String
}

enum NotificationReminderPlanner {
    static func reminderContent(for dueFriends: [Friend]) -> (title: String, body: String)? {
        let sortedDueFriends = FriendCheckInPrioritizer.sortedByDueDate(dueFriends)
        guard let firstFriend = sortedDueFriends.first else {
            return nil
        }

        let firstName = firstFriend.firstName
        let title = "Check in with \(firstName)"
        let remainingFirstNames = sortedDueFriends.dropFirst().prefix(2).map(\.firstName)

        if remainingFirstNames.isEmpty {
            return (title, "Consider taking some time to talk to \(firstName) today")
        }

        let alternatives = remainingFirstNames.joined(separator: " or ")
        return (title, "Or, consider reaching out to \(alternatives)")
    }

    static func regularReminderPlans(
        friends: [Friend],
        dates: [Date],
        identifier: (Int) -> String
    ) -> [NotificationReminderPlan] {
        dates.enumerated().compactMap { index, date in
            let dueFriends = dueFriends(from: friends, at: date)
            guard let content = reminderContent(for: dueFriends) else {
                return nil
            }

            return NotificationReminderPlan(
                identifier: identifier(index),
                date: date,
                title: content.title,
                body: content.body
            )
        }
    }

    static func dueReminderPlans(
        friends: [Friend],
        reminderDate: (Friend) -> Date,
        identifier: (Friend) -> String,
        now: Date = .now
    ) -> [NotificationReminderPlan] {
        friends.compactMap { friend in
            let date = reminderDate(friend)
            guard date > now else {
                return nil
            }

            let dueFriends = dueFriends(from: friends, at: date)
            guard dueFriends.contains(where: { $0.id == friend.id }),
                  let content = reminderContent(for: dueFriends) else {
                return nil
            }

            return NotificationReminderPlan(
                identifier: identifier(friend),
                date: date,
                title: content.title,
                body: content.body
            )
        }
    }

    private static func dueFriends(from friends: [Friend], at date: Date) -> [Friend] {
        friends.filter { $0.dueDate <= date }
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
            scheduleRegularReminders(for: [friend])
        case .whenCheckInIsDue:
            cancelRegularReminder()
            scheduleDueReminders(for: [friend])
        }
    }

    static func syncReminders(for friends: [Friend]) {
        switch currentDeliveryMode {
        case .none:
            cancelRegularReminder()
            friends.forEach(cancelDueReminder)
        case .regularCycle:
            friends.forEach(cancelDueReminder)
            scheduleRegularReminders(for: friends)
        case .whenCheckInIsDue:
            cancelRegularReminder()
            scheduleDueReminders(for: friends)
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

    private static func scheduleDueReminders(for friends: [Friend]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: friends.map(notificationIdentifier))

        for plan in NotificationReminderPlanner.dueReminderPlans(
            friends: friends,
            reminderDate: nextReminderDate,
            identifier: notificationIdentifier
        ) {
            center.add(notificationRequest(for: plan))
        }
    }

    private static func scheduleRegularReminders(for friends: [Friend]) {
        let center = UNUserNotificationCenter.current()
        cancelRegularReminder()

        for plan in NotificationReminderPlanner.regularReminderPlans(
            friends: friends,
            dates: upcomingRegularReminderDates(),
            identifier: regularReminderIdentifier
        ) {
            center.add(notificationRequest(for: plan))
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
        let calendar = Calendar.current
        let startOfDueDay = calendar.startOfDay(for: friend.dueDate)
        let reminderDate = calendar.date(bySettingHour: currentDueHour, minute: currentDueMinute, second: 0, of: startOfDueDay) ?? friend.dueDate

        guard reminderDate < friend.dueDate else {
            return reminderDate
        }

        return calendar.date(byAdding: .day, value: 1, to: reminderDate) ?? friend.dueDate
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

    private static func notificationRequest(for plan: NotificationReminderPlan) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = plan.title
        content.body = plan.body
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: plan.date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        return UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger)
    }
}

import Foundation

enum FriendCheckInPrioritizer {
    static func sortedByDueDate(_ friends: [Friend]) -> [Friend] {
        friends.sorted { lhs, rhs in
            if lhs.dueDate != rhs.dueDate {
                return lhs.dueDate < rhs.dueDate
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    static func topFriendsByDueDate(_ friends: [Friend], maxCount: Int = 3) -> [Friend] {
        guard maxCount > 0 else {
            return []
        }

        return Array(sortedByDueDate(friends).prefix(maxCount))
    }

    static func dueOrPastDueFriends(from sortedFriends: [Friend], maxCount: Int = 3, now: Date = .now) -> [Friend] {
        guard maxCount > 0 else {
            return []
        }

        return Array(sortedFriends.filter { $0.dueDate <= now }.prefix(maxCount))
    }

    static func topDueOrPastDueFriends(_ friends: [Friend], maxCount: Int = 3, now: Date = .now) -> [Friend] {
        dueOrPastDueFriends(from: sortedByDueDate(friends), maxCount: maxCount, now: now)
    }
}

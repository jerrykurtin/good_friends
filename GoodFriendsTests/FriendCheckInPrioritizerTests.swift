import XCTest
@testable import GoodFriends

final class FriendCheckInPrioritizerTests: XCTestCase {
    func testSortedByDueDateHandlesNewOneCheckInAndMultipleCheckIns() {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newFriend = makeFriend(firstName: "New", createdAt: baseDate, thresholdDays: 40)
        let oneCheckInFriend = makeFriend(
            firstName: "One Check In",
            createdAt: baseDate,
            thresholdDays: 10,
            checkInDates: [baseDate.addingTimeInterval(20 * day)]
        )
        let multipleCheckInsFriend = makeFriend(
            firstName: "Multiple Check Ins",
            createdAt: baseDate,
            thresholdDays: 10,
            checkInDates: [
                baseDate.addingTimeInterval(2 * day),
                baseDate.addingTimeInterval(4 * day)
            ]
        )

        let sorted = FriendCheckInPrioritizer.sortedByDueDate([
            newFriend,
            oneCheckInFriend,
            multipleCheckInsFriend
        ])

        XCTAssertEqual(sorted.map(\.displayName), [
            "Multiple Check Ins",
            "One Check In",
            "New"
        ])
    }

    func testSortedByDueDateHandlesFutureCheckIns() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let futureDate = Date(timeIntervalSince1970: 4_102_444_800)
        let currentlyDueFriend = makeFriend(firstName: "Currently Due", createdAt: now, thresholdDays: 1)
        let futureCheckInFriend = makeFriend(
            firstName: "Future Check In",
            createdAt: now,
            thresholdDays: 30,
            checkInDates: [futureDate]
        )

        let sorted = FriendCheckInPrioritizer.sortedByDueDate([
            futureCheckInFriend,
            currentlyDueFriend
        ])

        XCTAssertEqual(sorted.map(\.displayName), ["Currently Due", "Future Check In"])
    }

    func testSortedByDueDateHandlesEpochCheckIns() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let epochFriend = makeFriend(
            firstName: "Epoch",
            createdAt: now,
            thresholdDays: 1,
            checkInDates: [Date(timeIntervalSince1970: 0)]
        )
        let recentFriend = makeFriend(firstName: "Recent", createdAt: now, thresholdDays: 1)

        let sorted = FriendCheckInPrioritizer.sortedByDueDate([recentFriend, epochFriend])

        XCTAssertEqual(sorted.map(\.displayName), ["Epoch", "Recent"])
    }

    func testLatestCompletedCheckInIgnoresSkippedCheckIns() {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let checkedInDate = baseDate.addingTimeInterval(day)
        let skippedDate = baseDate.addingTimeInterval(2 * day)
        let friend = Friend(firstName: "Skipped Later", createdAt: baseDate)
        friend.checkIns = [
            CheckIn(date: checkedInDate, kind: .checkedIn),
            CheckIn(date: skippedDate, kind: .skipped)
        ]

        XCTAssertEqual(friend.latestCompletedCheckInDate, checkedInDate)
    }

    func testSortedByDueDateStillConsidersSkippedCheckIns() {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let checkedOnlyFriend = makeFriend(
            firstName: "Checked Only",
            createdAt: baseDate,
            thresholdDays: 10,
            checkInDates: [baseDate.addingTimeInterval(10 * day)]
        )
        let skippedRecentlyFriend = Friend(firstName: "Skipped Recently", thresholdDays: 10, createdAt: baseDate)
        skippedRecentlyFriend.checkIns = [
            CheckIn(date: baseDate.addingTimeInterval(day), kind: .checkedIn),
            CheckIn(date: baseDate.addingTimeInterval(20 * day), kind: .skipped)
        ]

        let sorted = FriendCheckInPrioritizer.sortedByDueDate([
            skippedRecentlyFriend,
            checkedOnlyFriend
        ])

        XCTAssertEqual(sorted.map(\.displayName), ["Checked Only", "Skipped Recently"])
    }

    func testTopFriendsByDueDateReturnsClosestFriendsWithoutFilteringDueStatus() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let dueFriend = makeDueFriend(firstName: "Due", daysOverdue: 1, now: now)
        let nextSoon = makeFutureFriend(firstName: "Next Soon", daysUntilDue: 1, now: now)
        let nextLater = makeFutureFriend(firstName: "Next Later", daysUntilDue: 3, now: now)
        let tooFar = makeFutureFriend(firstName: "Too Far", daysUntilDue: 10, now: now)

        let topFriends = FriendCheckInPrioritizer.topFriendsByDueDate(
            [tooFar, nextLater, dueFriend, nextSoon],
            maxCount: 3
        )

        XCTAssertEqual(topFriends.map(\.displayName), ["Due", "Next Soon", "Next Later"])
    }

    func testFilteringWhenDueFriendsAreGreaterThanMaxReturnsMaxCount() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sorted = FriendCheckInPrioritizer.sortedByDueDate([
            makeDueFriend(firstName: "Fourth", daysOverdue: 4, now: now),
            makeDueFriend(firstName: "Second", daysOverdue: 20, now: now),
            makeFutureFriend(firstName: "Future", daysUntilDue: 2, now: now),
            makeDueFriend(firstName: "Oldest", daysOverdue: 30, now: now),
            makeDueFriend(firstName: "Third", daysOverdue: 10, now: now)
        ])

        let dueFriends = FriendCheckInPrioritizer.dueOrPastDueFriends(from: sorted, maxCount: 3, now: now)

        XCTAssertEqual(dueFriends.map(\.displayName), ["Oldest", "Second", "Third"])
    }

    func testFilteringWhenDueFriendsEqualMaxReturnsAllDueFriends() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sorted = FriendCheckInPrioritizer.sortedByDueDate([
            makeDueFriend(firstName: "Third", daysOverdue: 3, now: now),
            makeDueFriend(firstName: "First", daysOverdue: 9, now: now),
            makeFutureFriend(firstName: "Future", daysUntilDue: 1, now: now),
            makeDueFriend(firstName: "Second", daysOverdue: 6, now: now)
        ])

        let dueFriends = FriendCheckInPrioritizer.dueOrPastDueFriends(from: sorted, maxCount: 3, now: now)

        XCTAssertEqual(dueFriends.map(\.displayName), ["First", "Second", "Third"])
    }

    func testFilteringWhenDueFriendsAreLessThanMaxReturnsOnlyDueFriends() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sorted = FriendCheckInPrioritizer.sortedByDueDate([
            makeFutureFriend(firstName: "Future Two", daysUntilDue: 2, now: now),
            makeDueFriend(firstName: "Due Today", daysOverdue: 0, now: now),
            makeFutureFriend(firstName: "Future One", daysUntilDue: 1, now: now),
            makeDueFriend(firstName: "Overdue", daysOverdue: 4, now: now)
        ])

        let dueFriends = FriendCheckInPrioritizer.dueOrPastDueFriends(from: sorted, maxCount: 3, now: now)

        XCTAssertEqual(dueFriends.map(\.displayName), ["Overdue", "Due Today"])
    }

    func testFilteringWhenNoFriendsAreDueReturnsEmptyList() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sorted = FriendCheckInPrioritizer.sortedByDueDate([
            makeFutureFriend(firstName: "Future One", daysUntilDue: 1, now: now),
            makeFutureFriend(firstName: "Future Two", daysUntilDue: 2, now: now)
        ])

        let dueFriends = FriendCheckInPrioritizer.dueOrPastDueFriends(from: sorted, maxCount: 3, now: now)

        XCTAssertTrue(dueFriends.isEmpty)
    }

    private func makeDueFriend(firstName: String, daysOverdue: Int, now: Date) -> Friend {
        makeFriend(firstName: firstName, createdAt: date(byAddingDays: -(10 + daysOverdue), to: now), thresholdDays: 10)
    }

    private func makeFutureFriend(firstName: String, daysUntilDue: Int, now: Date) -> Friend {
        makeFriend(firstName: firstName, createdAt: date(byAddingDays: -(10 - daysUntilDue), to: now), thresholdDays: 10)
    }

    private func makeFriend(
        firstName: String,
        createdAt: Date,
        thresholdDays: Int,
        checkInDates: [Date] = []
    ) -> Friend {
        let friend = Friend(firstName: firstName, thresholdDays: thresholdDays, createdAt: createdAt)
        friend.checkIns = checkInDates.map { date in
            CheckIn(date: date)
        }

        return friend
    }

    private func date(byAddingDays days: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }

    private var day: TimeInterval { 86_400 }
}

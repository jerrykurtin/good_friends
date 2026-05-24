import XCTest
@testable import GoodFriends

final class FriendCheckInPrioritizerTests: XCTestCase {
    func testSortedByDueDateHandlesNewOneCheckInAndMultipleCheckIns() {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newFriend = makeFriend(name: "New", createdAt: baseDate, thresholdDays: 40)
        let oneCheckInFriend = makeFriend(
            name: "One Check In",
            createdAt: baseDate,
            thresholdDays: 10,
            checkInDates: [baseDate.addingTimeInterval(20 * day)]
        )
        let multipleCheckInsFriend = makeFriend(
            name: "Multiple Check Ins",
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

        XCTAssertEqual(sorted.map(\.name), [
            "Multiple Check Ins",
            "One Check In",
            "New"
        ])
    }

    func testSortedByDueDateHandlesFutureCheckIns() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let futureDate = Date(timeIntervalSince1970: 4_102_444_800)
        let currentlyDueFriend = makeFriend(name: "Currently Due", createdAt: now, thresholdDays: 1)
        let futureCheckInFriend = makeFriend(
            name: "Future Check In",
            createdAt: now,
            thresholdDays: 30,
            checkInDates: [futureDate]
        )

        let sorted = FriendCheckInPrioritizer.sortedByDueDate([
            futureCheckInFriend,
            currentlyDueFriend
        ])

        XCTAssertEqual(sorted.map(\.name), ["Currently Due", "Future Check In"])
    }

    func testSortedByDueDateHandlesEpochCheckIns() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let epochFriend = makeFriend(
            name: "Epoch",
            createdAt: now,
            thresholdDays: 1,
            checkInDates: [Date(timeIntervalSince1970: 0)]
        )
        let recentFriend = makeFriend(name: "Recent", createdAt: now, thresholdDays: 1)

        let sorted = FriendCheckInPrioritizer.sortedByDueDate([recentFriend, epochFriend])

        XCTAssertEqual(sorted.map(\.name), ["Epoch", "Recent"])
    }

    func testLatestCompletedCheckInIgnoresSkippedCheckIns() {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let checkedInDate = baseDate.addingTimeInterval(day)
        let skippedDate = baseDate.addingTimeInterval(2 * day)
        let friend = Friend(name: "Skipped Later", createdAt: baseDate)
        friend.checkIns = [
            CheckIn(date: checkedInDate, kind: .checkedIn, friend: friend),
            CheckIn(date: skippedDate, kind: .skipped, friend: friend)
        ]

        XCTAssertEqual(friend.latestCompletedCheckInDate, checkedInDate)
    }

    func testSortedByDueDateStillConsidersSkippedCheckIns() {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let checkedOnlyFriend = makeFriend(
            name: "Checked Only",
            createdAt: baseDate,
            thresholdDays: 10,
            checkInDates: [baseDate.addingTimeInterval(10 * day)]
        )
        let skippedRecentlyFriend = Friend(name: "Skipped Recently", thresholdDays: 10, createdAt: baseDate)
        skippedRecentlyFriend.checkIns = [
            CheckIn(date: baseDate.addingTimeInterval(day), kind: .checkedIn, friend: skippedRecentlyFriend),
            CheckIn(date: baseDate.addingTimeInterval(20 * day), kind: .skipped, friend: skippedRecentlyFriend)
        ]

        let sorted = FriendCheckInPrioritizer.sortedByDueDate([
            skippedRecentlyFriend,
            checkedOnlyFriend
        ])

        XCTAssertEqual(sorted.map(\.name), ["Checked Only", "Skipped Recently"])
    }

    func testTopFriendsByDueDateReturnsClosestFriendsWithoutFilteringDueStatus() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let dueFriend = makeDueFriend(name: "Due", daysOverdue: 1, now: now)
        let nextSoon = makeFutureFriend(name: "Next Soon", daysUntilDue: 1, now: now)
        let nextLater = makeFutureFriend(name: "Next Later", daysUntilDue: 3, now: now)
        let tooFar = makeFutureFriend(name: "Too Far", daysUntilDue: 10, now: now)

        let topFriends = FriendCheckInPrioritizer.topFriendsByDueDate(
            [tooFar, nextLater, dueFriend, nextSoon],
            maxCount: 3
        )

        XCTAssertEqual(topFriends.map(\.name), ["Due", "Next Soon", "Next Later"])
    }

    func testFilteringWhenDueFriendsAreGreaterThanMaxReturnsMaxCount() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sorted = FriendCheckInPrioritizer.sortedByDueDate([
            makeDueFriend(name: "Fourth", daysOverdue: 4, now: now),
            makeDueFriend(name: "Second", daysOverdue: 20, now: now),
            makeFutureFriend(name: "Future", daysUntilDue: 2, now: now),
            makeDueFriend(name: "Oldest", daysOverdue: 30, now: now),
            makeDueFriend(name: "Third", daysOverdue: 10, now: now)
        ])

        let dueFriends = FriendCheckInPrioritizer.dueOrPastDueFriends(from: sorted, maxCount: 3, now: now)

        XCTAssertEqual(dueFriends.map(\.name), ["Oldest", "Second", "Third"])
    }

    func testFilteringWhenDueFriendsEqualMaxReturnsAllDueFriends() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sorted = FriendCheckInPrioritizer.sortedByDueDate([
            makeDueFriend(name: "Third", daysOverdue: 3, now: now),
            makeDueFriend(name: "First", daysOverdue: 9, now: now),
            makeFutureFriend(name: "Future", daysUntilDue: 1, now: now),
            makeDueFriend(name: "Second", daysOverdue: 6, now: now)
        ])

        let dueFriends = FriendCheckInPrioritizer.dueOrPastDueFriends(from: sorted, maxCount: 3, now: now)

        XCTAssertEqual(dueFriends.map(\.name), ["First", "Second", "Third"])
    }

    func testFilteringWhenDueFriendsAreLessThanMaxReturnsOnlyDueFriends() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sorted = FriendCheckInPrioritizer.sortedByDueDate([
            makeFutureFriend(name: "Future Two", daysUntilDue: 2, now: now),
            makeDueFriend(name: "Due Today", daysOverdue: 0, now: now),
            makeFutureFriend(name: "Future One", daysUntilDue: 1, now: now),
            makeDueFriend(name: "Overdue", daysOverdue: 4, now: now)
        ])

        let dueFriends = FriendCheckInPrioritizer.dueOrPastDueFriends(from: sorted, maxCount: 3, now: now)

        XCTAssertEqual(dueFriends.map(\.name), ["Overdue", "Due Today"])
    }

    func testFilteringWhenNoFriendsAreDueReturnsEmptyList() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sorted = FriendCheckInPrioritizer.sortedByDueDate([
            makeFutureFriend(name: "Future One", daysUntilDue: 1, now: now),
            makeFutureFriend(name: "Future Two", daysUntilDue: 2, now: now)
        ])

        let dueFriends = FriendCheckInPrioritizer.dueOrPastDueFriends(from: sorted, maxCount: 3, now: now)

        XCTAssertTrue(dueFriends.isEmpty)
    }

    private func makeDueFriend(name: String, daysOverdue: Int, now: Date) -> Friend {
        makeFriend(name: name, createdAt: date(byAddingDays: -(10 + daysOverdue), to: now), thresholdDays: 10)
    }

    private func makeFutureFriend(name: String, daysUntilDue: Int, now: Date) -> Friend {
        makeFriend(name: name, createdAt: date(byAddingDays: -(10 - daysUntilDue), to: now), thresholdDays: 10)
    }

    private func makeFriend(
        name: String,
        createdAt: Date,
        thresholdDays: Int,
        checkInDates: [Date] = []
    ) -> Friend {
        let friend = Friend(name: name, thresholdDays: thresholdDays, createdAt: createdAt)
        friend.checkIns = checkInDates.map { date in
            CheckIn(date: date, friend: friend)
        }

        return friend
    }

    private func date(byAddingDays days: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }

    private var day: TimeInterval { 86_400 }
}

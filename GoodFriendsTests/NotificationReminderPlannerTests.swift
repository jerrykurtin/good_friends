import XCTest
@testable import GoodFriends

final class NotificationReminderPlannerTests: XCTestCase {
    func testReminderContentReturnsNilWhenNoFriendsAreDue() {
        XCTAssertNil(NotificationReminderPlanner.reminderContent(for: []))
    }

    func testReminderContentForOneDueFriendUsesFirstNameInTitleAndBody() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let friend = makeDueFriend(firstName: "Avery", daysOverdue: 2, now: now)

        let content = NotificationReminderPlanner.reminderContent(for: [friend])

        XCTAssertEqual(content?.title, "Check in with Avery")
        XCTAssertEqual(content?.body, "Consider taking some time to talk to Avery today")
    }

    func testReminderContentForMultipleDueFriendsUsesMostDueInTitleAndNextTwoInBody() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let oldest = makeDueFriend(firstName: "Oldest", daysOverdue: 20, now: now)
        let second = makeDueFriend(firstName: "Second", daysOverdue: 10, now: now)
        let third = makeDueFriend(firstName: "Third", daysOverdue: 5, now: now)
        let fourth = makeDueFriend(firstName: "Fourth", daysOverdue: 1, now: now)

        let content = NotificationReminderPlanner.reminderContent(for: [fourth, third, oldest, second])

        XCTAssertEqual(content?.title, "Check in with Oldest")
        XCTAssertEqual(content?.body, "Or, consider reaching out to Second or Third")
    }

    func testRegularReminderPlansSkipDatesWithNoDueFriends() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let triggerBeforeDue = date(byAddingDays: 2, to: now)
        let triggerAfterDue = date(byAddingDays: 4, to: now)
        let friend = makeFutureFriend(firstName: "Soon", daysUntilDue: 3, now: now)

        let plans = NotificationReminderPlanner.regularReminderPlans(
            friends: [friend],
            dates: [triggerBeforeDue, triggerAfterDue],
            identifier: { "regular-\($0)" }
        )

        XCTAssertEqual(plans.map(\.identifier), ["regular-1"])
        XCTAssertEqual(plans.first?.date, triggerAfterDue)
        XCTAssertEqual(plans.first?.title, "Check in with Soon")
    }

    func testRegularReminderPlansUseDueFriendsAtEachTriggerDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let firstTrigger = date(byAddingDays: 1, to: now)
        let secondTrigger = date(byAddingDays: 3, to: now)
        let alreadyDue = makeDueFriend(firstName: "Already", daysOverdue: 4, now: now)
        let dueLater = makeFutureFriend(firstName: "Later", daysUntilDue: 2, now: now)

        let plans = NotificationReminderPlanner.regularReminderPlans(
            friends: [dueLater, alreadyDue],
            dates: [firstTrigger, secondTrigger],
            identifier: { "regular-\($0)" }
        )

        XCTAssertEqual(plans.count, 2)
        XCTAssertEqual(plans[0].title, "Check in with Already")
        XCTAssertEqual(plans[0].body, "Consider taking some time to talk to Already today")
        XCTAssertEqual(plans[1].title, "Check in with Already")
        XCTAssertEqual(plans[1].body, "Or, consider reaching out to Later")
    }

    func testDueReminderPlansUseDueFriendsAtFriendsReminderDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let firstDue = makeFutureFriend(firstName: "First", daysUntilDue: 1, now: now)
        let secondDue = makeFutureFriend(firstName: "Second", daysUntilDue: 1, now: now)
        let later = makeFutureFriend(firstName: "Later", daysUntilDue: 3, now: now)

        let plans = NotificationReminderPlanner.dueReminderPlans(
            friends: [later, secondDue, firstDue],
            reminderDate: { $0.dueDate },
            identifier: { $0.firstName },
            now: now
        )

        let firstPlan = plans.first { $0.identifier == "First" }
        XCTAssertEqual(firstPlan?.title, "Check in with First")
        XCTAssertEqual(firstPlan?.body, "Or, consider reaching out to Second")
    }

    private func makeDueFriend(firstName: String, daysOverdue: Int, now: Date) -> Friend {
        makeFriend(firstName: firstName, createdAt: date(byAddingDays: -(10 + daysOverdue), to: now), thresholdDays: 10)
    }

    private func makeFutureFriend(firstName: String, daysUntilDue: Int, now: Date) -> Friend {
        makeFriend(firstName: firstName, createdAt: date(byAddingDays: -(10 - daysUntilDue), to: now), thresholdDays: 10)
    }

    private func makeFriend(firstName: String, createdAt: Date, thresholdDays: Int) -> Friend {
        Friend(firstName: firstName, thresholdDays: thresholdDays, createdAt: createdAt)
    }

    private func date(byAddingDays days: Int, to date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: date) ?? date
    }
}

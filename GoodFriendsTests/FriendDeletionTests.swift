import SwiftData
import XCTest
@testable import GoodFriends

final class FriendDeletionTests: XCTestCase {
    @MainActor
    func testDeletingFriendRemovesTheirCheckIns() throws {
        let container = try makeContainer()
        let modelContext = container.mainContext
        let friend = Friend(name: "Maya", groupName: "College")
        let firstCheckIn = CheckIn(date: .now, note: "Coffee", friend: friend)
        let secondCheckIn = CheckIn(date: .now.addingTimeInterval(-86_400), note: "Call", friend: friend)

        friend.checkIns.append(contentsOf: [firstCheckIn, secondCheckIn])
        modelContext.insert(friend)
        modelContext.insert(firstCheckIn)
        modelContext.insert(secondCheckIn)
        try modelContext.save()

        try FriendDataStore.delete(friend, in: modelContext)

        let remainingFriends = try modelContext.fetch(FetchDescriptor<Friend>())
        let remainingCheckIns = try modelContext.fetch(FetchDescriptor<CheckIn>())
        XCTAssertTrue(remainingFriends.isEmpty)
        XCTAssertTrue(remainingCheckIns.isEmpty)
    }

    @MainActor
    func testDeletingOneFriendKeepsOtherFriendsCheckIns() throws {
        let container = try makeContainer()
        let modelContext = container.mainContext
        let deletedFriend = Friend(name: "Maya", groupName: "College")
        let keptFriend = Friend(name: "Noah", groupName: "Work")
        let deletedCheckIn = CheckIn(date: .now, note: "Coffee", friend: deletedFriend)
        let keptCheckIn = CheckIn(date: .now, note: "Dinner", friend: keptFriend)

        deletedFriend.checkIns.append(deletedCheckIn)
        keptFriend.checkIns.append(keptCheckIn)
        modelContext.insert(deletedFriend)
        modelContext.insert(keptFriend)
        modelContext.insert(deletedCheckIn)
        modelContext.insert(keptCheckIn)
        try modelContext.save()

        try FriendDataStore.delete(deletedFriend, in: modelContext)

        let remainingFriends = try modelContext.fetch(FetchDescriptor<Friend>())
        let remainingCheckIns = try modelContext.fetch(FetchDescriptor<CheckIn>())
        XCTAssertEqual(remainingFriends.map(\.name), ["Noah"])
        XCTAssertEqual(remainingCheckIns.map(\.note), ["Dinner"])
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Friend.self, CheckIn.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

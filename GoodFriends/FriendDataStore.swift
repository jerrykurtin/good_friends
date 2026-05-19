import SwiftData

enum FriendDataStore {
    static func delete(_ friend: Friend, in modelContext: ModelContext) throws {
        modelContext.delete(friend)
        try modelContext.save()
    }
}

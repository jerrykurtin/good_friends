import Foundation
import SwiftData

enum SampleData {
    static func seedIfNeeded(in modelContext: ModelContext) {
        var descriptor = FetchDescriptor<Friend>()
        descriptor.fetchLimit = 1

        guard let existingFriends = try? modelContext.fetch(descriptor), existingFriends.isEmpty else {
            return
        }

        for sampleFriend in friends {
            let friend = Friend(
                name: sampleFriend.name,
                city: sampleFriend.city,
                groupName: sampleFriend.groupName,
                notes: sampleFriend.notes,
                thresholdDays: sampleFriend.thresholdDays,
                createdAt: date(daysAgo: sampleFriend.createdDaysAgo)
            )

            modelContext.insert(friend)

            for sampleCheckIn in sampleFriend.checkIns {
                let checkIn = CheckIn(
                    date: date(daysAgo: sampleCheckIn.daysAgo),
                    note: sampleCheckIn.note,
                    friend: friend
                )
                friend.checkIns.append(checkIn)
                modelContext.insert(checkIn)
            }
        }

        try? modelContext.save()
    }

    private static let friends: [SampleFriend] = [
        SampleFriend(
            name: "Maya Chen",
            city: "Chicago",
            groupName: "College",
            notes: "Ask about the new ceramics studio.",
            thresholdDays: 21,
            createdDaysAgo: 240,
            checkIns: [
                SampleCheckIn(daysAgo: 4, note: "Sent photos from the weekend."),
                SampleCheckIn(daysAgo: 32, note: "Caught up after work.")
            ]
        ),
        SampleFriend(name: "Daniel Brooks", city: "Seattle", groupName: "College", notes: "Planning a fall hiking trip.", thresholdDays: 30, createdDaysAgo: 260, checkIns: [SampleCheckIn(daysAgo: 48, note: "Quick call before dinner.")]),
        SampleFriend(name: "Priya Nair", city: "Austin", groupName: "College", notes: "Loves low-key Sunday calls.", thresholdDays: 14, createdDaysAgo: 180, checkIns: [SampleCheckIn(daysAgo: 8, note: "Talked about her new role.")]),
        SampleFriend(name: "Leo Martinez", city: "Denver", groupName: "College", notes: "Remember his marathon training.", thresholdDays: 21, createdDaysAgo: 220, checkIns: []),
        SampleFriend(name: "Sophie Laurent", city: "Boston", groupName: "College", notes: "Send book recommendations.", thresholdDays: 45, createdDaysAgo: 210, checkIns: [SampleCheckIn(daysAgo: 19, note: "Texted about a novel.")]),

        SampleFriend(name: "Avery Kim", city: "New York", groupName: "Work", notes: "Former product partner.", thresholdDays: 30, createdDaysAgo: 160, checkIns: [SampleCheckIn(daysAgo: 2, note: "Lunch near Bryant Park.")]),
        SampleFriend(name: "Jordan Patel", city: "San Francisco", groupName: "Work", notes: "Ask about the startup.", thresholdDays: 21, createdDaysAgo: 190, checkIns: [SampleCheckIn(daysAgo: 27, note: "Shared notes on hiring.")]),
        SampleFriend(name: "Nina Rossi", city: "Portland", groupName: "Work", notes: "Recently moved apartments.", thresholdDays: 30, createdDaysAgo: 175, checkIns: []),
        SampleFriend(name: "Sam Okafor", city: "Atlanta", groupName: "Work", notes: "Basketball and coffee.", thresholdDays: 14, createdDaysAgo: 130, checkIns: [SampleCheckIn(daysAgo: 11, note: "Voice memo about playoffs.")]),
        SampleFriend(name: "Elena Garcia", city: "Los Angeles", groupName: "Work", notes: "Design systems brain trust.", thresholdDays: 45, createdDaysAgo: 155, checkIns: [SampleCheckIn(daysAgo: 61, note: "Talked conference plans.")]),

        SampleFriend(name: "Miles Turner", city: "Philadelphia", groupName: "Family Friends", notes: "Grew up on the same block.", thresholdDays: 30, createdDaysAgo: 300, checkIns: [SampleCheckIn(daysAgo: 16, note: "Checked in after his trip.")]),
        SampleFriend(name: "Grace Lee", city: "San Diego", groupName: "Family Friends", notes: "Ask about her garden.", thresholdDays: 21, createdDaysAgo: 280, checkIns: [SampleCheckIn(daysAgo: 35, note: "Sent birthday message.")]),
        SampleFriend(name: "Owen Wright", city: "Minneapolis", groupName: "Family Friends", notes: "Usually prefers texts.", thresholdDays: 45, createdDaysAgo: 260, checkIns: []),
        SampleFriend(name: "Hannah Cohen", city: "Miami", groupName: "Family Friends", notes: "New puppy stories.", thresholdDays: 30, createdDaysAgo: 210, checkIns: [SampleCheckIn(daysAgo: 6, note: "FaceTime on Sunday.")]),
        SampleFriend(name: "Marcus Reed", city: "Nashville", groupName: "Family Friends", notes: "Music recommendations.", thresholdDays: 60, createdDaysAgo: 250, checkIns: [SampleCheckIn(daysAgo: 78, note: "Caught up during holidays.")]),

        SampleFriend(name: "Tessa Morgan", city: "New Orleans", groupName: "Neighborhood", notes: "Former neighbor, excellent cook.", thresholdDays: 21, createdDaysAgo: 140, checkIns: [SampleCheckIn(daysAgo: 14, note: "Swapped recipes.")]),
        SampleFriend(name: "Ben Adler", city: "Raleigh", groupName: "Neighborhood", notes: "Ask about the twins.", thresholdDays: 30, createdDaysAgo: 165, checkIns: [SampleCheckIn(daysAgo: 42, note: "Texted after the move.")]),
        SampleFriend(name: "Clara Singh", city: "Phoenix", groupName: "Neighborhood", notes: "Always down for a voice note.", thresholdDays: 14, createdDaysAgo: 120, checkIns: [SampleCheckIn(daysAgo: 1, note: "Sent a quick hello.")]),
        SampleFriend(name: "Ethan Park", city: "Salt Lake City", groupName: "Neighborhood", notes: "Climbing updates.", thresholdDays: 21, createdDaysAgo: 150, checkIns: []),
        SampleFriend(name: "Rachel Stein", city: "Washington, DC", groupName: "Neighborhood", notes: "Ask about her museum project.", thresholdDays: 45, createdDaysAgo: 155, checkIns: [SampleCheckIn(daysAgo: 23, note: "Coffee while she was visiting.")])
    ]

    private static func date(daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
    }
}

private struct SampleFriend {
    let name: String
    let city: String
    let groupName: String
    let notes: String
    let thresholdDays: Int
    let createdDaysAgo: Int
    let checkIns: [SampleCheckIn]
}

private struct SampleCheckIn {
    let daysAgo: Int
    let note: String
}

import Foundation
import SwiftData

@Model
final class Friend {
    @Attribute(.unique) var id: UUID
    var name: String
    var city: String
    var groupName: String
    var notes: String
    var thresholdDays: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \CheckIn.friend)
    var checkIns: [CheckIn]

    init(
        id: UUID = UUID(),
        name: String,
        city: String = "",
        groupName: String = "Friends",
        notes: String = "",
        thresholdDays: Int = 30,
        createdAt: Date = .now,
        checkIns: [CheckIn] = []
    ) {
        self.id = id
        self.name = name
        self.city = city
        self.groupName = groupName
        self.notes = notes
        self.thresholdDays = thresholdDays
        self.createdAt = createdAt
        self.checkIns = checkIns
    }

    var latestCheckIn: CheckIn? {
        checkIns.max { $0.date < $1.date }
    }

    var latestCheckInDate: Date? {
        latestCheckIn?.date
    }

    var dueDate: Date {
        let baseDate = latestCheckInDate ?? createdAt
        return Calendar.current.date(byAdding: .day, value: thresholdDays, to: baseDate) ?? baseDate
    }

    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: dueDate)).day ?? 0
    }

    var isDue: Bool {
        dueDate <= .now
    }
}

@Model
final class CheckIn {
    @Attribute(.unique) var id: UUID
    var date: Date
    var note: String
    var friend: Friend?

    init(id: UUID = UUID(), date: Date = .now, note: String = "", friend: Friend? = nil) {
        self.id = id
        self.date = date
        self.note = note
        self.friend = friend
    }
}

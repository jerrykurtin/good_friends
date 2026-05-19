import Foundation
import SwiftData

@Model
final class Friend {
    @Attribute(.unique) var id: UUID
    var name: String
    var city: String
    var groupName: String
    var groupColorHex: String?
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
        groupColorHex: String? = nil,
        notes: String = "",
        thresholdDays: Int = 30,
        createdAt: Date = .now,
        checkIns: [CheckIn] = []
    ) {
        self.id = id
        self.name = name
        self.city = city
        self.groupName = groupName
        self.groupColorHex = groupColorHex
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

    var resolvedGroupColorHex: String {
        guard let groupColorHex,
              !groupColorHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return GroupColorPalette.defaultHex(for: groupName)
        }

        return groupColorHex
    }
}

enum GroupColorPalette {
    static let options = [
        "#6a5acd",
        "#cd1c18",
        "#ffc067",
        "#007BA7",
        "#568203",
        "#2D68C4"
    ]

    static func defaultHex(for groupName: String) -> String {
        let normalized = groupName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let total = normalized.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return options[total % options.count]
    }
}

@Model
final class CheckIn {
    @Attribute(.unique) var id: UUID
    var date: Date
    var note: String
    var kindRawValue: String
    var friend: Friend?

    init(id: UUID = UUID(), date: Date = .now, note: String = "", kind: CheckInKind = .checkedIn, friend: Friend? = nil) {
        self.id = id
        self.date = date
        self.note = note
        self.kindRawValue = kind.rawValue
        self.friend = friend
    }

    var kind: CheckInKind {
        get {
            CheckInKind(rawValue: kindRawValue) ?? .checkedIn
        }
        set {
            kindRawValue = newValue.rawValue
        }
    }
}

enum CheckInKind: String, Codable {
    case checkedIn
    case skipped

    var title: String {
        switch self {
        case .checkedIn: "Checked in"
        case .skipped: "Skipped"
        }
    }
}

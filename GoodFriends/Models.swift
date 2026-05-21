import Foundation
import SwiftData

@Model
final class Friend {
    @Attribute(.unique) var id: UUID
    var name: String
    var city: String
    // Groups are deliberately stored as lightweight friend fields instead of a separate model.
    // If groups need richer data later, this should become its own model.
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
        "Lavender": "#6a5acd",
        "Chili": "#cd1c18",
        "Pumpkin": "#e9610a",
        "Olive": "#568203",
        "Royal": "#2D68C4",
        "Chocolate": "#654321",
        "Kale": "#2c5f34"
    ]

    static var sortedOptions: [(name: String, hex: String)] {
        options.keys.sorted().compactMap { name in
            guard let hex = options[name] else {
                return nil
            }

            return (name, hex)
        }
    }

    static func defaultHex(for groupName: String) -> String {
        let normalized = groupName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let total = normalized.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let options = sortedOptions
        guard !options.isEmpty else {
            return "#6a5acd"
        }

        return options[total % options.count].hex
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

enum CheckInKind: String, Codable, CaseIterable, Identifiable {
    var id: Self { self }

    case checkedIn
    case skipped

    var title: String {
        switch self {
        case .checkedIn: "Checked in"
        case .skipped: "Skipped"
        }
    }
}

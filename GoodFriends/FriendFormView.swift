import SwiftData
import SwiftUI

struct FriendFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let friend: Friend?

    @State private var name: String
    @State private var city: String
    @State private var groupName: String
    @State private var notes: String
    @State private var reminderCadence: ReminderCadence
    @State private var customReminderValue: String
    @State private var customReminderUnit: CustomReminderUnit

    init(friend: Friend? = nil) {
        let thresholdDays = friend?.thresholdDays ?? 30
        let cadence = ReminderCadence(thresholdDays: thresholdDays)

        self.friend = friend
        _name = State(initialValue: friend?.name ?? "")
        _city = State(initialValue: friend?.city ?? "")
        _groupName = State(initialValue: friend?.groupName ?? "")
        _notes = State(initialValue: friend?.notes ?? "")
        _reminderCadence = State(initialValue: cadence)
        _customReminderValue = State(initialValue: Self.initialCustomValue(for: thresholdDays, cadence: cadence))
        _customReminderUnit = State(initialValue: Self.initialCustomUnit(for: thresholdDays, cadence: cadence))
    }

    var body: some View {
        Form {
            Section("Friend") {
                TextField("Name", text: $name)
                TextField("City", text: $city)
                TextField("Group", text: $groupName)
            }

            Section("Reminder") {
                Picker("Check in frequency", selection: $reminderCadence) {
                    ForEach(ReminderCadence.allCases) { cadence in
                        Text(cadence.title).tag(cadence)
                    }
                }

                if reminderCadence == .custom {
                    HStack(spacing: 10) {
                        Spacer()

                        Text("Every")
                            .foregroundStyle(.secondary)

                        TextField("Number", text: $customReminderValue)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .frame(width: 64)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.tint.opacity(0.12), in: Capsule())
                            .overlay {
                                Capsule()
                                    .strokeBorder(.tint.opacity(0.45), lineWidth: 1)
                            }

                        Picker("", selection: $customReminderUnit) {
                            ForEach(CustomReminderUnit.allCases) { unit in
                                Text(unit.title).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .tint(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.tint.opacity(0.12), in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(.tint.opacity(0.45), lineWidth: 1)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Notes") {
                TextField("Things to ask about", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(friend == nil ? "Add Friend" : "Edit Friend")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(!canSave)
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && resolvedThresholdDays != nil
    }

    private var resolvedThresholdDays: Int? {
        if let days = reminderCadence.thresholdDays {
            return days
        }

        guard let value = Int(customReminderValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              value > 0 else {
            return nil
        }

        return customReminderUnit.days(for: value)
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroupName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let thresholdDays = resolvedThresholdDays ?? 30

        let savedFriend: Friend
        if let friend {
            friend.name = cleanName
            friend.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
            friend.groupName = cleanGroupName.isEmpty ? "Friends" : cleanGroupName
            friend.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            friend.thresholdDays = thresholdDays
            savedFriend = friend
        } else {
            let friend = Friend(
                name: cleanName,
                city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                groupName: cleanGroupName.isEmpty ? "Friends" : cleanGroupName,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                thresholdDays: thresholdDays
            )
            modelContext.insert(friend)
            savedFriend = friend
        }

        try? modelContext.save()
        NotificationScheduler.scheduleReminder(for: savedFriend)
        dismiss()
    }

    private static func initialCustomValue(for thresholdDays: Int, cadence: ReminderCadence) -> String {
        guard cadence == .custom else {
            return "1"
        }

        if thresholdDays >= 30 && thresholdDays.isMultiple(of: 30) {
            return "\(thresholdDays / 30)"
        }

        return "\(thresholdDays)"
    }

    private static func initialCustomUnit(for thresholdDays: Int, cadence: ReminderCadence) -> CustomReminderUnit {
        guard cadence == .custom else {
            return .days
        }

        return thresholdDays >= 30 && thresholdDays.isMultiple(of: 30) ? .months : .days
    }
}

private enum ReminderCadence: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case monthly
    case everyTwoMonths
    case twiceAYear
    case yearly
    case custom

    var id: Self { self }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .everyTwoMonths: "Every 2 months"
        case .twiceAYear: "Twice a year"
        case .yearly: "Yearly"
        case .custom: "Custom"
        }
    }

    var thresholdDays: Int? {
        switch self {
        case .daily: 1
        case .weekly: 7
        case .monthly: 30
        case .everyTwoMonths: 60
        case .twiceAYear: 183
        case .yearly: 365
        case .custom: nil
        }
    }

    init(thresholdDays: Int) {
        switch thresholdDays {
        case 1:
            self = .daily
        case 7:
            self = .weekly
        case 30:
            self = .monthly
        case 60:
            self = .everyTwoMonths
        case 183:
            self = .twiceAYear
        case 365:
            self = .yearly
        default:
            self = .custom
        }
    }
}

private enum CustomReminderUnit: String, CaseIterable, Identifiable {
    case days
    case months

    var id: Self { self }

    var title: String {
        switch self {
        case .days: "Days"
        case .months: "Months"
        }
    }

    func days(for value: Int) -> Int {
        switch self {
        case .days:
            value
        case .months:
            value * 30
        }
    }
}

import SwiftData
import SwiftUI

struct FriendFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Friend.groupName) private var friends: [Friend]

    private let friend: Friend?
    private let onDelete: (() -> Void)?
    private static let newGroupOption = "__new_group__"

    @State private var name: String
    @State private var city: String
    @State private var groupName: String
    @State private var isAddingNewGroup: Bool
    @State private var notes: String
    @State private var reminderCadence: ReminderCadence
    @State private var customReminderValue: String
    @State private var customReminderUnit: CustomReminderUnit
    @State private var showingDeleteConfirmation = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case groupName
    }

    init(friend: Friend? = nil, onDelete: (() -> Void)? = nil) {
        let thresholdDays = friend?.thresholdDays ?? 30
        let cadence = ReminderCadence(thresholdDays: thresholdDays)

        self.friend = friend
        self.onDelete = onDelete
        _name = State(initialValue: friend?.name ?? "")
        _city = State(initialValue: friend?.city ?? "")
        _groupName = State(initialValue: friend?.groupName ?? "")
        _isAddingNewGroup = State(initialValue: false)
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

                if isAddingNewGroup || availableGroupNames.isEmpty {
                    HStack {
                        TextField("New group", text: $groupName)
                            .focused($focusedField, equals: .groupName)

                        if !availableGroupNames.isEmpty {
                            Button("Choose Existing") {
                                isAddingNewGroup = false
                                groupName = availableGroupNames.first ?? ""
                                focusedField = nil
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }
                } else {
                    Picker("Group", selection: $groupName) {
                        ForEach(availableGroupNames, id: \.self) { group in
                            Text(group).tag(group)
                        }

                        Divider()

                        Text("Add New Group").tag(Self.newGroupOption)
                    }
                    .onChange(of: groupName) { _, newValue in
                        if newValue == Self.newGroupOption {
                            isAddingNewGroup = true
                            groupName = ""
                            focusNewGroupField()
                        }
                    }
                }
            }

            Section("Reminder") {
                Picker("Check in frequency", selection: $reminderCadence) {
                    ForEach(ReminderCadence.formOptions) { cadence in
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

            if friend != nil {
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Text("Delete Friend")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .onAppear {
            if groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let firstGroup = availableGroupNames.first {
                groupName = firstGroup
            }
        }
        .onChange(of: isAddingNewGroup) { _, isAddingNewGroup in
            if isAddingNewGroup {
                focusNewGroupField()
            }
        }
        .alert("Delete this friend?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive, action: deleteFriend)
        } message: {
            Text("This will remove the friend and their check-in history.")
        }
        .navigationTitle(friend == nil ? "Add Friend" : "Edit Friend")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .tint(.secondary)
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

    private var availableGroupNames: [String] {
        Array(
            Set(
                friends
                .map { $0.groupName.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            )
        ).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
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
        let cleanGroupName = groupName == Self.newGroupOption ? "" : groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedGroupName = cleanGroupName.isEmpty ? "Friends" : cleanGroupName
        let savedGroupColorHex = colorHex(for: savedGroupName)
        let thresholdDays = resolvedThresholdDays ?? 30

        let savedFriend: Friend
        if let friend {
            friend.name = cleanName
            friend.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
            friend.groupName = savedGroupName
            friend.groupColorHex = savedGroupColorHex
            friend.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            friend.thresholdDays = thresholdDays
            savedFriend = friend
        } else {
            let friend = Friend(
                name: cleanName,
                city: city.trimmingCharacters(in: .whitespacesAndNewlines),
                groupName: savedGroupName,
                groupColorHex: savedGroupColorHex,
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

    private func deleteFriend() {
        guard let friend else {
            return
        }

        NotificationScheduler.cancelReminder(for: friend)
        try? FriendDataStore.delete(friend, in: modelContext)
        dismiss()
        onDelete?()
    }

    private func focusNewGroupField() {
        DispatchQueue.main.async {
            focusedField = .groupName
        }
    }

    private func colorHex(for groupName: String) -> String {
        if let matchingFriend = friends.first(where: {
            $0.groupName.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(groupName) == .orderedSame
        }) {
            return matchingFriend.resolvedGroupColorHex
        }

        return GroupColorPalette.defaultHex(for: groupName)
    }

    private static func initialCustomValue(for thresholdDays: Int, cadence: ReminderCadence) -> String {
        guard cadence == .custom else {
            return "1"
        }

        if thresholdDays >= 30 && thresholdDays.isMultiple(of: 30) {
            return "\(thresholdDays / 30)"
        }

        if thresholdDays.isMultiple(of: 7) {
            return "\(thresholdDays / 7)"
        }

        return "\(thresholdDays)"
    }

    private static func initialCustomUnit(for thresholdDays: Int, cadence: ReminderCadence) -> CustomReminderUnit {
        guard cadence == .custom else {
            return .days
        }

        if thresholdDays >= 30 && thresholdDays.isMultiple(of: 30) {
            return .months
        }

        if thresholdDays.isMultiple(of: 7) {
            return .weeks
        }

        return .days
    }
}

private enum ReminderCadence: String, CaseIterable, Identifiable {
    case weekly
    case monthly
    case everyTwoMonths
    case twiceAYear
    case yearly
    case custom

    var id: Self { self }

    static var formOptions: [ReminderCadence] {
        [.weekly, .monthly, .everyTwoMonths, .twiceAYear, .yearly, .custom]
    }

    var title: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .everyTwoMonths: "Every 2 months"
        case .twiceAYear: "Every six months"
        case .yearly: "Yearly"
        case .custom: "Custom"
        }
    }

    var thresholdDays: Int? {
        switch self {
        case .weekly: 7
        case .monthly: 30
        case .everyTwoMonths: 60
        case .twiceAYear: 180
        case .yearly: 365
        case .custom: nil
        }
    }

    init(thresholdDays: Int) {
        switch thresholdDays {
        case 7:
            self = .weekly
        case 30:
            self = .monthly
        case 60:
            self = .everyTwoMonths
        case 180:
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
    case weeks
    case months

    var id: Self { self }

    var title: String {
        switch self {
        case .days: "Days"
        case .weeks: "Weeks"
        case .months: "Months"
        }
    }

    func days(for value: Int) -> Int {
        switch self {
        case .days:
            value
        case .weeks:
            value * 7
        case .months:
            value * 30
        }
    }
}

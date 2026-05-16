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
    @State private var thresholdDays: Int

    init(friend: Friend? = nil) {
        self.friend = friend
        _name = State(initialValue: friend?.name ?? "")
        _city = State(initialValue: friend?.city ?? "")
        _groupName = State(initialValue: friend?.groupName ?? "")
        _notes = State(initialValue: friend?.notes ?? "")
        _thresholdDays = State(initialValue: friend?.thresholdDays ?? 30)
    }

    var body: some View {
        Form {
            Section("Friend") {
                TextField("Name", text: $name)
                TextField("City", text: $city)
                TextField("How you know them", text: $groupName)
            }

            Section("Reminder") {
                Stepper(value: $thresholdDays, in: 1...365) {
                    Text("Every \(thresholdDays) days")
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
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGroupName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)

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
}

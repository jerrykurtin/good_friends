import SwiftData
import SwiftUI

struct FriendDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var friend: Friend

    @State private var showingEditForm = false
    @State private var checkInNote = ""

    private var sortedCheckIns: [CheckIn] {
        friend.checkIns.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("City", value: friend.city.isEmpty ? "Not set" : friend.city)
                LabeledContent("Group", value: friend.groupName)
                LabeledContent("Reminder", value: "Every \(friend.thresholdDays) days")
                LabeledContent("Next due", value: friend.dueDate.formatted(date: .abbreviated, time: .omitted))

                if !friend.notes.isEmpty {
                    Text(friend.notes)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Check in") {
                TextField("Optional note", text: $checkInNote, axis: .vertical)
                    .lineLimit(2...5)

                Button {
                    recordCheckIn()
                } label: {
                    Label("Mark checked in", systemImage: "checkmark.circle.fill")
                }
            }

            Section("History") {
                if sortedCheckIns.isEmpty {
                    ContentUnavailableView("No check-ins yet", systemImage: "clock")
                } else {
                    ForEach(sortedCheckIns) { checkIn in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(checkIn.date.formatted(date: .abbreviated, time: .shortened))
                            if !checkIn.note.isEmpty {
                                Text(checkIn.note)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteCheckIns)
                }
            }
        }
        .navigationTitle(friend.name)
        .toolbar {
            Button("Edit") {
                showingEditForm = true
            }
        }
        .sheet(isPresented: $showingEditForm) {
            NavigationStack {
                FriendFormView(friend: friend)
            }
        }
    }

    private func recordCheckIn() {
        let cleanNote = checkInNote.trimmingCharacters(in: .whitespacesAndNewlines)

        if let latest = friend.latestCheckIn, Calendar.current.isDateInToday(latest.date) {
            latest.date = .now
            if !cleanNote.isEmpty {
                latest.note = cleanNote
            }
        } else {
            let checkIn = CheckIn(date: .now, note: cleanNote, friend: friend)
            friend.checkIns.append(checkIn)
            modelContext.insert(checkIn)
        }

        checkInNote = ""
        try? modelContext.save()
        NotificationScheduler.scheduleReminder(for: friend)
    }

    private func deleteCheckIns(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedCheckIns[index])
        }
        try? modelContext.save()
        NotificationScheduler.scheduleReminder(for: friend)
    }
}

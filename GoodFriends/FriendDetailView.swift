import SwiftData
import SwiftUI

struct FriendDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var friend: Friend

    @State private var showingEditForm = false
    @State private var checkInNote = ""
    @FocusState private var isCheckInNoteFocused: Bool

    private var sortedCheckIns: [CheckIn] {
        friend.checkIns.sorted { $0.date > $1.date }
    }

    private var reminderDescription: String {
        switch friend.thresholdDays {
        case 7:
            "Every week"
        case 30:
            "Every month"
        case 60:
            "Every 2 months"
        case 180:
            "Every 6 months"
        case 365:
            "Every 12 months"
        default:
            if friend.thresholdDays >= 30, friend.thresholdDays.isMultiple(of: 30) {
                "Every \(friend.thresholdDays / 30) months"
            } else if friend.thresholdDays.isMultiple(of: 7) {
                "Every \(friend.thresholdDays / 7) weeks"
            } else {
                "Every \(friend.thresholdDays) days"
            }
        }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("City", value: friend.city.isEmpty ? "Not set" : friend.city)
                LabeledContent("Group", value: friend.groupName)
                LabeledContent("Reminder", value: reminderDescription)
                LabeledContent("Next due", value: friend.dueDate.formatted(date: .abbreviated, time: .omitted))

                if !friend.notes.isEmpty {
                    Text(friend.notes)
                        .foregroundStyle(.secondary)
                }
            }
            .onTapGesture {
                isCheckInNoteFocused = false
            }

            Section("Check in") {
                TextField("Optional note", text: $checkInNote, axis: .vertical)
                    .focused($isCheckInNoteFocused)
                    .lineLimit(2...5)

                Button {
                    isCheckInNoteFocused = false
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
                        NavigationLink {
                            HistoryDetailView(checkIn: checkIn)
                        } label: {
                            HistoryRow(checkIn: checkIn)
                        }
                    }
                    .onDelete(perform: deleteCheckIns)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(friend.displayName)
        .toolbar {
            Button("Edit") {
                showingEditForm = true
            }
        }
        .sheet(isPresented: $showingEditForm) {
            NavigationStack {
                FriendFormView(friend: friend) {
                    dismiss()
                }
            }
        }
    }

    private func recordCheckIn() {
        let cleanNote = checkInNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let checkIn = CheckIn(date: .now, note: cleanNote, friend: friend)
        friend.checkIns.append(checkIn)
        modelContext.insert(checkIn)

        checkInNote = ""
        try? modelContext.save()
        NotificationScheduler.syncReminder(for: friend)
    }

    private func deleteCheckIns(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedCheckIns[index])
        }
        try? modelContext.save()
        NotificationScheduler.syncReminder(for: friend)
    }
}

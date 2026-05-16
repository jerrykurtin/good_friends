import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Friend.name) private var friends: [Friend]

    @State private var showingFriendForm = false

    private var surfacedFriends: [Friend] {
        friends
            .sorted {
                if $0.isDue != $1.isDue {
                    return $0.isDue && !$1.isDue
                }
                return $0.dueDate < $1.dueDate
            }
            .prefix(2)
            .map { $0 }
    }

    private var groupedFriends: [(name: String, friends: [Friend])] {
        Dictionary(grouping: friends) { $0.groupName.trimmedOrFallback("Friends") }
            .map { ($0.key, $0.value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if surfacedFriends.isEmpty {
                        ContentUnavailableView("Add a close friend", systemImage: "person.crop.circle.badge.plus", description: Text("Start with one or two people you want to stay close to."))
                    } else {
                        ForEach(surfacedFriends) { friend in
                            CatchUpCard(friend: friend) {
                                recordCheckIn(for: friend)
                            }
                        }
                    }
                } header: {
                    Text("Catch up next")
                }

                ForEach(groupedFriends, id: \.name) { group in
                    Section(group.name) {
                        ForEach(group.friends) { friend in
                            NavigationLink {
                                FriendDetailView(friend: friend)
                            } label: {
                                FriendRow(friend: friend)
                            }
                        }
                        .onDelete { offsets in
                            deleteFriends(at: offsets, from: group.friends)
                        }
                    }
                }
            }
            .navigationTitle("Good Friends")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingFriendForm = true
                    } label: {
                        Label("Add Friend", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingFriendForm) {
                NavigationStack {
                    FriendFormView()
                }
            }
            .onAppear {
                NotificationScheduler.requestAuthorization()
            }
        }
    }

    private func recordCheckIn(for friend: Friend) {
        if let latest = friend.latestCheckIn, Calendar.current.isDateInToday(latest.date) {
            latest.date = .now
        } else {
            let checkIn = CheckIn(date: .now, friend: friend)
            friend.checkIns.append(checkIn)
            modelContext.insert(checkIn)
        }

        try? modelContext.save()
        NotificationScheduler.scheduleReminder(for: friend)
    }

    private func deleteFriends(at offsets: IndexSet, from groupFriends: [Friend]) {
        for index in offsets {
            let friend = groupFriends[index]
            NotificationScheduler.cancelReminder(for: friend)
            modelContext.delete(friend)
        }
        try? modelContext.save()
    }
}

private struct CatchUpCard: View {
    let friend: Friend
    let onCheckIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.name)
                        .font(.headline)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(friend.isDue ? .red : .secondary)
                }

                Spacer()

                Text(friend.groupName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !friend.notes.isEmpty {
                Text(friend.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(action: onCheckIn) {
                Label("Checked in today", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 6)
    }

    private var statusText: String {
        if let latest = friend.latestCheckInDate {
            let relative = latest.formatted(.relative(presentation: .named))
            return friend.isDue ? "Last checked in \(relative)" : "Next reminder \(friend.dueDate.formatted(date: .abbreviated, time: .omitted))"
        }

        return friend.isDue ? "No check-ins yet" : "First reminder \(friend.dueDate.formatted(date: .abbreviated, time: .omitted))"
    }
}

private struct FriendRow: View {
    let friend: Friend

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(friend.name)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if friend.isDue {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Due")
            }
        }
    }

    private var subtitle: String {
        if let latest = friend.latestCheckInDate {
            return "Last check-in \(latest.formatted(date: .abbreviated, time: .omitted))"
        }
        return "Every \(friend.thresholdDays) days"
    }
}

private extension String {
    func trimmedOrFallback(_ fallback: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

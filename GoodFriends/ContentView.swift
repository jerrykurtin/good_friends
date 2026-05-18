import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: AppTab = .checkIn

    var body: some View {
        ZStack(alignment: .bottom) {
            selectedTab.view

            GlassTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
        }
        .onAppear {
            SampleData.seedIfNeeded(in: modelContext)
            NotificationScheduler.requestAuthorization()
        }
    }
}

private enum AppTab: String, CaseIterable, Identifiable {
    case checkIn
    case friends
    case history

    var id: Self { self }

    var title: String {
        switch self {
        case .checkIn: "Check In"
        case .friends: "Friends"
        case .history: "History"
        }
    }

    var symbolName: String {
        switch self {
        case .checkIn: "bubble.left.and.bubble.right"
        case .friends: "person.2"
        case .history: "clock.arrow.circlepath"
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .checkIn:
            CheckInTabView()
        case .friends:
            FriendsTabView()
        case .history:
            HistoryTabView()
        }
    }
}

private struct GlassTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbolName)
                            .font(.system(size: 17, weight: .semibold))

                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(.white.opacity(0.32))
                                .shadow(color: .white.opacity(0.35), radius: 8, x: 0, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 12)
    }
}

private struct CheckInTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Friend.name) private var friends: [Friend]
    @State private var showingCheckInDetails = false
    @State private var selectedCardIndex = 0

    private var overdueFriends: [Friend] {
        Array(friends.sorted { lhs, rhs in
            if lhs.dueDate != rhs.dueDate {
                return lhs.dueDate < rhs.dueDate
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }.prefix(3))
    }

    private var selectedFriend: Friend? {
        guard !overdueFriends.isEmpty else {
            return nil
        }

        return overdueFriends[selectedCardIndex % overdueFriends.count]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    if let friend = selectedFriend {
                        CheckInCardStack(friends: overdueFriends, selectedIndex: $selectedCardIndex) {
                            skipCheckIn(for: friend)
                        }

                        Button {
                            showingCheckInDetails = true
                        } label: {
                            Text("Check in")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .sheet(isPresented: $showingCheckInDetails) {
                            NavigationStack {
                                CheckInDetailsView(friend: friend)
                            }
                        }
                    } else {
                        ContentUnavailableView("Add a close friend", systemImage: "person.crop.circle.badge.plus")
                    }
                }
                .padding(20)
                .padding(.bottom, 86)
            }
            .navigationTitle("Check In")
            .onChange(of: overdueFriends.map(\.id)) { _, ids in
                if ids.isEmpty {
                    selectedCardIndex = 0
                } else if selectedCardIndex >= ids.count {
                    selectedCardIndex = 0
                }
            }
        }
    }

    private func skipCheckIn(for friend: Friend) {
        let checkIn = CheckIn(date: .now, kind: .skipped, friend: friend)
        friend.checkIns.append(checkIn)
        modelContext.insert(checkIn)

        try? modelContext.save()
        NotificationScheduler.scheduleReminder(for: friend)
    }
}

private struct CheckInCardStack: View {
    let friends: [Friend]
    @Binding var selectedIndex: Int
    let onSkip: () -> Void

    @GestureState private var dragTranslation: CGSize = .zero
    @State private var exitTranslation: CGSize = .zero
    @State private var isAnimatingExit = false

    var body: some View {
        ZStack {
            ForEach(Array(visibleCards.enumerated()).reversed(), id: \.element.id) { depth, friend in
                CheckInPromptCard(friend: friend, showsSkipButton: depth == 0, onSkip: onSkip)
                    .scaleEffect(scale(for: depth, progress: stackProgress))
                    .offset(offset(for: depth, progress: stackProgress))
                    .rotationEffect(rotation(for: depth))
                    .shadow(color: .black.opacity(shadowOpacity(for: depth)), radius: 24, x: 0, y: 10)
                    .zIndex(Double(friends.count - depth))
                    .allowsHitTesting(depth == 0)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 404)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .updating($dragTranslation) { value, state, _ in
                    guard !isAnimatingExit else {
                        return
                    }

                    state = value.translation
                }
                .onEnded { value in
                    handleDragEnd(value)
                }
        )
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: selectedIndex)
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: exitTranslation)
        .accessibilityElement(children: .contain)
    }

    private var activeTranslation: CGSize {
        isAnimatingExit ? exitTranslation : dragTranslation
    }

    private var stackProgress: CGFloat {
        min(1, abs(activeTranslation.width) / 180)
    }

    private var visibleCards: [Friend] {
        guard !friends.isEmpty else {
            return []
        }

        return friends.indices.map { offset in
            friends[(selectedIndex + offset) % friends.count]
        }
    }

    private func handleDragEnd(_ value: DragGesture.Value) {
        guard !friends.isEmpty, !isAnimatingExit else {
            return
        }

        let projectedWidth = value.predictedEndTranslation.width
        let shouldAdvance = abs(value.translation.width) > 110 || abs(projectedWidth) > 180

        guard shouldAdvance else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                exitTranslation = .zero
            }
            return
        }

        let direction = projectedWidth == 0 ? value.translation.width : projectedWidth
        let horizontalExit = direction >= 0 ? 720.0 : -720.0
        let verticalExit = value.translation.height + (value.predictedEndTranslation.height * 0.18)

        isAnimatingExit = true
        withAnimation(.easeInOut(duration: 0.28)) {
            exitTranslation = CGSize(width: horizontalExit, height: verticalExit)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            cycleCards()
            exitTranslation = .zero
            isAnimatingExit = false
        }
    }

    private func cycleCards() {
        guard !friends.isEmpty else {
            return
        }

        selectedIndex = (selectedIndex + 1) % friends.count
    }

    private func offset(for depth: Int, progress: CGFloat) -> CGSize {
        if depth == 0 {
            return activeTranslation
        }

        return CGSize(width: 0, height: yOffset(for: depth, progress: progress))
    }

    private func rotation(for depth: Int) -> Angle {
        guard depth == 0 else {
            return .degrees(0)
        }

        return .degrees(Double(activeTranslation.width / 28))
    }

    private func scale(for depth: Int, progress: CGFloat) -> CGFloat {
        let effectiveDepth = max(0, CGFloat(depth) - progress)
        return max(0.88, 1 - effectiveDepth * 0.055)
    }

    private func yOffset(for depth: Int, progress: CGFloat) -> CGFloat {
        let effectiveDepth = max(0, CGFloat(depth) - progress)
        return effectiveDepth * 22
    }

    private func shadowOpacity(for depth: Int) -> Double {
        depth == 0 ? 0.08 : 0.04
    }
}

private struct CheckInPromptCard: View {
    let friend: Friend
    let showsSkipButton: Bool
    let onSkip: () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.background)
            .overlay(alignment: .topTrailing) {
                if showsSkipButton {
                    Button("Skip check-in", action: onSkip)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .padding(18)
                }
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(friend.name)
                        .font(.title2.weight(.semibold))

                    Text(lastCheckInText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 360)
    }

    private var lastCheckInText: String {
        guard let date = friend.latestCheckInDate else {
            return "No check-ins yet"
        }

        return "Last checked in \(date.formatted(date: .abbreviated, time: .omitted))"
    }
}
private struct CheckInDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let friend: Friend

    @State private var checkInDate = Date()
    @State private var note = ""

    var body: some View {
        Form {
            Section("Friend") {
                LabeledContent("Name", value: friend.name)
                LabeledContent("Last check-in", value: lastCheckInText)
            }

            Section("Check-in date") {
                DatePicker("Date", selection: $checkInDate, displayedComponents: .date)
            }

            Section("Notes") {
                TextField("Optional note", text: $note, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle("Check In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add", action: save)
            }
        }
    }

    private var lastCheckInText: String {
        guard let date = friend.latestCheckInDate else {
            return "Never"
        }

        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func save() {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if Calendar.current.isDateInToday(checkInDate),
           let latest = friend.latestCheckIn,
           Calendar.current.isDateInToday(latest.date) {
            latest.date = checkInDate
            latest.kind = .checkedIn
            if !cleanNote.isEmpty {
                latest.note = cleanNote
            }
        } else {
            let checkIn = CheckIn(date: checkInDate, note: cleanNote, kind: .checkedIn, friend: friend)
            friend.checkIns.append(checkIn)
            modelContext.insert(checkIn)
        }

        try? modelContext.save()
        NotificationScheduler.scheduleReminder(for: friend)
        dismiss()
    }
}

private struct FriendsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Friend.name) private var friends: [Friend]

    @State private var showingFriendForm = false

    private var groupedFriends: [(name: String, friends: [Friend])] {
        Dictionary(grouping: friends) { $0.groupName.trimmedOrFallback("Friends") }
            .map { ($0.key, $0.value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                if friends.isEmpty {
                    ContentUnavailableView("Add a close friend", systemImage: "person.crop.circle.badge.plus")
                } else {
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
            }
            .contentMargins(.bottom, 86, for: .scrollContent)
            .navigationTitle("Friends")
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
        }
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

private struct HistoryTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]

    var body: some View {
        NavigationStack {
            List {
                if checkIns.isEmpty {
                    ContentUnavailableView("No check-ins yet", systemImage: "clock")
                } else {
                    ForEach(checkIns) { checkIn in
                        NavigationLink {
                            HistoryDetailView(checkIn: checkIn)
                        } label: {
                            HistoryRow(checkIn: checkIn)
                        }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(checkIn)
                                } label: {
                                    Image(systemName: "trash")
                                        .accessibilityLabel("Delete")
                                }
                            }
                    }
                }
            }
            .contentMargins(.bottom, 86, for: .scrollContent)
            .navigationTitle("History")
        }
    }

    private func delete(_ checkIn: CheckIn) {
        let friend = checkIn.friend
        modelContext.delete(checkIn)
        try? modelContext.save()

        if let friend {
            NotificationScheduler.scheduleReminder(for: friend)
        }
    }
}

private struct HistoryDetailView: View {
    let checkIn: CheckIn

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Type", value: checkIn.kind.title)
                LabeledContent("Friend", value: checkIn.friend?.name ?? "Deleted Friend")
                LabeledContent("Date", value: checkIn.date.formatted(date: .abbreviated, time: .omitted))
            }

            Section("Notes") {
                if checkIn.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("No notes")
                        .foregroundStyle(.secondary)
                } else {
                    Text(checkIn.note)
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HistoryRow: View {
    let checkIn: CheckIn

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(checkIn.kind.title) - \(checkIn.friend?.name ?? "Deleted Friend")")
                    .font(.body)
                Text(checkIn.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .opacity(checkIn.kind == .skipped ? 0.58 : 1)
        .listRowBackground(checkIn.kind == .skipped ? Color.clear : nil)
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
        return "No check-ins yet"
    }
}

private extension String {
    func trimmedOrFallback(_ fallback: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: AppTab = .checkIn
    @State private var tabTransitionDirection = 1

    var body: some View {
        ZStack(alignment: .bottom) {
            selectedTab.view
                .id(selectedTab)
                .transition(tabTransition)

            GlassTabBar(selectedTab: $selectedTab, tabTransitionDirection: $tabTransitionDirection)
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
                .zIndex(10)
        }
        .onAppear {
            SampleData.seedIfNeeded(in: modelContext)
            NotificationScheduler.requestAuthorization()
        }
        .tint(.goodFriendsAccent)
        .preferredColorScheme(.dark)
    }

    private var tabTransition: AnyTransition {
        if tabTransitionDirection >= 0 {
            .asymmetric(
                insertion: .move(edge: .trailing),
                removal: .move(edge: .leading)
            )
        } else {
            .asymmetric(
                insertion: .move(edge: .leading),
                removal: .move(edge: .trailing)
            )
        }
    }
}

private extension Color {
    static let goodFriendsAccent = Color(hex: "#249045")

    init(hex: String) {
        let components = Self.rgbComponents(for: hex)
        self.init(red: components.red, green: components.green, blue: components.blue)
    }

    static func mutedCardColor(hex: String) -> Color {
        let components = rgbComponents(for: hex)

        return Color(
            red: components.red * 0.46 + 0.14,
            green: components.green * 0.46 + 0.14,
            blue: components.blue * 0.46 + 0.14
        )
    }

    static func mutedCardShadowColor(hex: String) -> Color {
        let components = rgbComponents(for: hex)

        return Color(
            red: components.red * 0.38 + 0.10,
            green: components.green * 0.38 + 0.10,
            blue: components.blue * 0.38 + 0.10
        )
    }

    private static func rgbComponents(for hex: String) -> (red: Double, green: Double, blue: Double) {
        let cleanedHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleanedHex).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255

        return (red, green, blue)
    }
}

private struct AppNavigationHeader: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
    }
}

private extension View {
    func appNavigationHeader(_ title: String) -> some View {
        modifier(AppNavigationHeader(title: title))
    }
}

private enum AppTab: String, CaseIterable, Identifiable {
    case checkIn
    case friends
    case history

    var id: Self { self }

    var order: Int {
        switch self {
        case .checkIn: 0
        case .friends: 1
        case .history: 2
        }
    }

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
    @Binding var tabTransitionDirection: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    guard selectedTab != tab else {
                        return
                    }

                    tabTransitionDirection = tab.order > selectedTab.order ? 1 : -1
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
                        selectedTab = tab
                    }
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
    @State private var showingFriendForm = false
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
                        .zIndex(2)

                        Button {
                            showingCheckInDetails = true
                        } label: {
                            Text("Check in")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .zIndex(0)
                        .sheet(isPresented: $showingCheckInDetails) {
                            NavigationStack {
                                CheckInDetailsView(friend: friend)
                            }
                        }
                    } else {
                        Button {
                            showingFriendForm = true
                        } label: {
                            ContentUnavailableView("Add a close friend", systemImage: "person.crop.circle.badge.plus")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .padding(.bottom, 86)
            }
            .appNavigationHeader("Check In")
            .onChange(of: overdueFriends.map(\.id)) { _, ids in
                if ids.isEmpty {
                    selectedCardIndex = 0
                } else if selectedCardIndex >= ids.count {
                    selectedCardIndex = 0
                }
            }
            .sheet(isPresented: $showingFriendForm) {
                NavigationStack {
                    FriendFormView()
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

    @State private var dragTranslation: CGSize = .zero
    @State private var exitTranslation: CGSize = .zero
    @State private var isAnimatingExit = false

    var body: some View {
        ZStack {
            ForEach(Array(visibleCards.enumerated()).reversed(), id: \.element.id) { depth, friend in
                CheckInPromptCard(friend: friend, showsSkipButton: depth == 0, onSkip: onSkip)
                    .scaleEffect(scale(for: depth, progress: stackProgress))
                    .offset(offset(for: depth, progress: stackProgress))
                    .rotationEffect(rotation(for: depth))
                    .shadow(color: .black.opacity(shadowOpacity(for: depth)), radius: 30, x: 0, y: 18)
                    .shadow(color: .white.opacity(highlightOpacity(for: depth)), radius: 18, x: 0, y: -6)
                    .zIndex(Double(friends.count - depth))
                    .allowsHitTesting(depth == 0)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 404)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onChanged { value in
                    guard !isAnimatingExit else {
                        return
                    }

                    dragTranslation = value.translation
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
                dragTranslation = .zero
            }
            return
        }

        let direction = projectedWidth == 0 ? value.translation.width : projectedWidth
        let horizontalExit = direction >= 0 ? 720.0 : -720.0
        let verticalExit = value.translation.height + (value.predictedEndTranslation.height * 0.18)

        exitTranslation = value.translation
        isAnimatingExit = true
        withAnimation(.easeInOut(duration: 0.28)) {
            exitTranslation = CGSize(width: horizontalExit, height: verticalExit)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            cycleCards()
            exitTranslation = .zero
            dragTranslation = .zero
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
        depth == 0 ? 0.42 : 0.24
    }

    private func highlightOpacity(for depth: Int) -> Double {
        depth == 0 ? 0.10 : 0.05
    }
}

private struct CheckInPromptCard: View {
    let friend: Friend
    let showsSkipButton: Bool
    let onSkip: () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.mutedCardColor(hex: friend.resolvedGroupColorHex),
                        Color.mutedCardShadowColor(hex: friend.resolvedGroupColorHex)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                if showsSkipButton {
                    Button("Skip check-in", action: onSkip)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .tint(.gray.opacity(0.45))
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
    @FocusState private var isNoteFocused: Bool

    var body: some View {
        Form {
            Section("Friend") {
                LabeledContent("Name", value: friend.name)
                LabeledContent("Last check-in", value: lastCheckInText)
            }
            .onTapGesture {
                isNoteFocused = false
            }

            Section("Check-in date") {
                DatePicker("Date", selection: $checkInDate, displayedComponents: .date)
            }
            .onTapGesture {
                isNoteFocused = false
            }

            Section("Notes") {
                TextField("Optional note", text: $note, axis: .vertical)
                    .focused($isNoteFocused)
                    .lineLimit(3...6)
            }
        }
        .scrollDismissesKeyboard(.interactively)
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
        let checkIn = CheckIn(date: checkInDate.withCurrentTime(), note: cleanNote, kind: .checkedIn, friend: friend)
        friend.checkIns.append(checkIn)
        modelContext.insert(checkIn)

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
                    Button {
                        showingFriendForm = true
                    } label: {
                        ContentUnavailableView("Add a close friend", systemImage: "person.crop.circle.badge.plus")
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(groupedFriends, id: \.name) { group in
                        Section {
                            ForEach(group.friends) { friend in
                                NavigationLink {
                                    FriendDetailView(friend: friend)
                                } label: {
                                    FriendRow(friend: friend)
                                }
                            }
                        } header: {
                            GroupSectionHeader(
                                name: group.name,
                                colorHex: groupColorHex(for: group),
                                onSelectColor: { colorHex in
                                    setColor(colorHex, for: group)
                                }
                            )
                        }
                    }
                }
            }
            .contentMargins(.bottom, 86, for: .scrollContent)
            .appNavigationHeader("Friends")
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

    private func groupColorHex(for group: (name: String, friends: [Friend])) -> String {
        group.friends.first?.resolvedGroupColorHex ?? GroupColorPalette.defaultHex(for: group.name)
    }

    private func setColor(_ colorHex: String, for group: (name: String, friends: [Friend])) {
        for friend in group.friends {
            friend.groupColorHex = colorHex
        }

        try? modelContext.save()
    }
}

private struct GroupSectionHeader: View {
    let name: String
    let colorHex: String
    let onSelectColor: (String) -> Void

    @State private var showingColorPicker = false

    var body: some View {
        HStack {
            Label {
                Text(name)
            } icon: {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 10, height: 10)
            }

            Spacer()

            Button {
                showingColorPicker.toggle()
            } label: {
                Image(systemName: "paintpalette")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change \(name) color")
            .popover(isPresented: $showingColorPicker, arrowEdge: .top) {
                GroupColorPickerPopover(
                    selectedColorHex: colorHex,
                    onSelectColor: { colorHex in
                        onSelectColor(colorHex)
                        showingColorPicker = false
                    }
                )
                .presentationCompactAdaptation(.popover)
            }
        }
        .textCase(nil)
    }
}

private struct GroupColorPickerPopover: View {
    let selectedColorHex: String
    let onSelectColor: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(GroupColorPalette.sortedOptions, id: \.name) { option in
                let isSelected = option.hex.caseInsensitiveCompare(selectedColorHex) == .orderedSame

                Button {
                    onSelectColor(option.hex)
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: option.hex))
                            .frame(width: 14, height: 14)

                        Text(option.name)
                            .foregroundStyle(.primary)

                        Spacer(minLength: 18)

                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(minWidth: 170, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .presentationCompactAdaptation(.popover)
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
                                .tint(.red)
                            }
                    }
                }
            }
            .contentMargins(.bottom, 86, for: .scrollContent)
            .appNavigationHeader("History")
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

struct HistoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var checkIn: CheckIn
    @FocusState private var isNoteFocused: Bool

    private var checkInKind: Binding<CheckInKind> {
        Binding(
            get: { checkIn.kind },
            set: { checkIn.kind = $0 }
        )
    }

    private var checkInDate: Binding<Date> {
        Binding(
            get: { checkIn.date },
            set: { checkIn.date = $0.withTime(from: checkIn.date) }
        )
    }

    var body: some View {
        Form {
            Section("Details") {
                Picker("Type", selection: checkInKind) {
                    ForEach(CheckInKind.allCases) { kind in
                        Text(kind.title)
                            .tag(kind)
                    }
                }

                LabeledContent("Friend", value: checkIn.friend?.name ?? "Deleted Friend")
                DatePicker("Date", selection: checkInDate, displayedComponents: .date)
            }
            .onTapGesture {
                isNoteFocused = false
            }

            Section("Notes") {
                TextField("Optional notes", text: $checkIn.note, axis: .vertical)
                    .focused($isNoteFocused)
                    .lineLimit(3...8)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear(perform: save)
    }

    private func save() {
        checkIn.note = checkIn.note.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()

        if let friend = checkIn.friend {
            NotificationScheduler.scheduleReminder(for: friend)
        }
    }
}

struct HistoryRow: View {
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

private extension Date {
    func withCurrentTime(calendar: Calendar = .current, now: Date = .now) -> Date {
        withTime(from: now, calendar: calendar)
    }

    func withTime(from sourceDate: Date, calendar: Calendar = .current) -> Date {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: self)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: sourceDate)
        var components = DateComponents()
        components.calendar = calendar
        components.year = dayComponents.year
        components.month = dayComponents.month
        components.day = dayComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        components.nanosecond = timeComponents.nanosecond

        return calendar.date(from: components) ?? self
    }
}

private extension String {
    func trimmedOrFallback(_ fallback: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

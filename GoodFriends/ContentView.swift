import SwiftData
import SwiftUI
import SpriteKit
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: AppTab = .checkIn

    var body: some View {
        TabView(selection: $selectedTab) {
            CheckInTabView()
                .tabItem {
                    Label(AppTab.checkIn.title, systemImage: AppTab.checkIn.symbolName)
                }
                .tag(AppTab.checkIn)

            FriendsTabView()
                .tabItem {
                    Label(AppTab.friends.title, systemImage: AppTab.friends.symbolName)
                }
                .tag(AppTab.friends)

            HistoryTabView()
                .tabItem {
                    Label(AppTab.history.title, systemImage: AppTab.history.symbolName)
                }
                .tag(AppTab.history)

            StatsTabView()
                .tabItem {
                    Label(AppTab.stats.title, systemImage: AppTab.stats.symbolName)
                }
                .tag(AppTab.stats)
        }
        .onAppear {
            configureNativeTabBarAppearance()
            SampleData.seedIfNeeded(in: modelContext)
            NotificationScheduler.requestAuthorization()
        }
        .tint(.goodFriendsAccent)
        .preferredColorScheme(.dark)
    }

    private func configureNativeTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        configureTabBarItems(appearance.stackedLayoutAppearance)
        configureTabBarItems(appearance.inlineLayoutAppearance)
        configureTabBarItems(appearance.compactInlineLayoutAppearance)

        let tabBar = UITabBar.appearance()
        tabBar.tintColor = .goodFriendsAccent
        tabBar.unselectedItemTintColor = .secondaryLabel
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
    }

    private func configureTabBarItems(_ itemAppearance: UITabBarItemAppearance) {
        itemAppearance.selected.iconColor = .goodFriendsAccent
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.goodFriendsAccent]
        itemAppearance.normal.iconColor = .secondaryLabel
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.secondaryLabel]
    }
}

private extension UIColor {
    static let goodFriendsAccent = UIColor(red: 0x24 / 255, green: 0x90 / 255, blue: 0x45 / 255, alpha: 1)
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

private struct AppNavigationImageHeader: ViewModifier {
    let imageName: String
    let accessibilityLabel: String

    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image(imageName)
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 36)
                        .accessibilityLabel(accessibilityLabel)
                }
            }
    }
}

private extension View {
    func appNavigationHeader(_ title: String) -> some View {
        modifier(AppNavigationHeader(title: title))
    }

    func appNavigationImageHeader(_ imageName: String, accessibilityLabel: String) -> some View {
        modifier(AppNavigationImageHeader(imageName: imageName, accessibilityLabel: accessibilityLabel))
    }
}

private enum AppTab: String, CaseIterable, Identifiable {
    case checkIn
    case friends
    case history
    case stats

    var id: Self { self }

    var order: Int {
        switch self {
        case .checkIn: 0
        case .friends: 1
        case .history: 2
        case .stats: 3
        }
    }

    var title: String {
        switch self {
        case .checkIn: "Check In"
        case .friends: "Friends"
        case .history: "History"
        case .stats: "Stats"
        }
    }

    var symbolName: String {
        switch self {
        case .checkIn: "bubble.left.and.bubble.right"
        case .friends: "person.2"
        case .history: "clock.arrow.circlepath"
        case .stats: "chart.bar"
        }
    }

}

private struct CheckInTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Friend.name) private var friends: [Friend]
    @State private var showingCheckInDetails = false
    @State private var showingFriendForm = false
    @State private var selectedCardIndex = 0
    @State private var isShowingNextUp = false
    @State private var dismissedFriendIDs = Set<UUID>()

    private var availableFriends: [Friend] {
        friends.filter { !dismissedFriendIDs.contains($0.id) }
    }

    private var overdueFriends: [Friend] {
        FriendCheckInPrioritizer.topDueOrPastDueFriends(availableFriends)
    }

    private var nextUpFriends: [Friend] {
        FriendCheckInPrioritizer.topFriendsByDueDate(availableFriends)
    }

    private var cardFriends: [Friend] {
        if !overdueFriends.isEmpty {
            return overdueFriends
        }

        return isShowingNextUp ? nextUpFriends : []
    }

    private var selectedFriend: Friend? {
        guard !cardFriends.isEmpty else {
            return nil
        }

        return cardFriends[selectedCardIndex % cardFriends.count]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 18) {
                    if let friend = selectedFriend {
                        CheckInCardStack(friends: cardFriends, selectedIndex: $selectedCardIndex) {
                            skipCheckIn(for: friend)
                        }
                        .zIndex(2)

                        Button {
                            showingCheckInDetails = true
                        } label: {
                            Image("CheckInButtonTextWhite")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 32)
                                .frame(maxWidth: .infinity)
                                .accessibilityLabel("Check in")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .zIndex(0)
                        .sheet(isPresented: $showingCheckInDetails) {
                            NavigationStack {
                                CheckInDetailsView(friend: friend) {
                                    dismissFromCurrentCheckInSession(friend)
                                }
                            }
                        }
                    } else if friends.isEmpty {
                        Button {
                            showingFriendForm = true
                        } label: {
                            ContentUnavailableView("Add a close friend", systemImage: "person.crop.circle.badge.plus")
                        }
                        .buttonStyle(.plain)
                    } else if availableFriends.isEmpty {
                        AllCaughtUpView()
                    } else {
                        AllCaughtUpView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 404)

                        Button {
                            selectedCardIndex = 0
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                                isShowingNextUp = true
                            }
                        } label: {
                            Image("UpNextButtonText")
                                .renderingMode(.original)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 32)
                                .frame(maxWidth: .infinity)
                                .accessibilityLabel("See who's next up")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding(20)
            }
            .appNavigationImageHeader("GoodFriendsHeader", accessibilityLabel: "GOOD FRiENDS")
            .onChange(of: cardFriends.map(\.id)) { _, ids in
                if ids.isEmpty {
                    selectedCardIndex = 0
                    isShowingNextUp = false
                } else if selectedCardIndex >= ids.count {
                    selectedCardIndex = 0
                }
            }
            .sheet(isPresented: $showingFriendForm) {
                NavigationStack {
                    FriendFormView()
                }
            }
            .onDisappear {
                dismissedFriendIDs.removeAll()
                selectedCardIndex = 0
                isShowingNextUp = false
            }
        }
    }

    private func skipCheckIn(for friend: Friend) {
        let checkIn = CheckIn(date: .now, kind: .skipped, friend: friend)
        friend.checkIns.append(checkIn)
        modelContext.insert(checkIn)

        try? modelContext.save()
        NotificationScheduler.scheduleReminder(for: friend)
        dismissFromCurrentCheckInSession(friend)
    }

    private func dismissFromCurrentCheckInSession(_ friend: Friend) {
        dismissedFriendIDs.insert(friend.id)
        selectedCardIndex = 0
    }
}

private struct AllCaughtUpView: View {
    var body: some View {
        ContentUnavailableView {
            Label {
                Text("All caught up")
            } icon: {
                AllCaughtUpHeartIcon()
            }
        }
    }
}

private struct AllCaughtUpHeartIcon: View {
    @State private var isHeartVisible = false

    var body: some View {
        ZStack {
            Image(systemName: "heart")
                .hidden()

            if isHeartVisible {
                heartImage
            }
        }
        .onAppear {
            showHeartAfterDelay()
        }
    }

    @ViewBuilder
    private var heartImage: some View {
        if #available(iOS 26.0, *) {
            Image(systemName: "heart")
                .transition(.symbolEffect(.drawOn.wholeSymbol))
        } else {
            Image(systemName: "heart")
                .transition(.opacity.combined(with: .scale(scale: 0.82)))
        }
    }

    private func showHeartAfterDelay() {
        guard !isHeartVisible else {
            return
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.25))

            guard !isHeartVisible else {
                return
            }

            withAnimation(.easeOut(duration: 1.8)) {
                isHeartVisible = true
            }
        }
    }
}

private struct CheckInCardStack: View {
    let friends: [Friend]
    @Binding var selectedIndex: Int
    let onSkip: () -> Void

    @State private var dragTranslation: CGSize = .zero
    @State private var exitTranslation: CGSize = .zero
    @State private var isAnimatingExit = false
    @State private var skipPopScale: CGFloat = 1
    @State private var skipPopOpacity: Double = 1
    @State private var skipProgress: CGFloat = 0
    @State private var flippedFriendID: UUID?

    var body: some View {
        ZStack {
            ForEach(Array(visibleCards.enumerated()).reversed(), id: \.element.id) { depth, friend in
                CheckInPromptCard(
                    friend: friend,
                    showsSkipButton: depth == 0,
                    isFlipped: depth == 0 && flippedFriendID == friend.id,
                    onSkip: beginSkipAnimation
                )
                    .scaleEffect(scale(for: depth, progress: stackProgress) * popScale(for: depth))
                    .opacity(opacity(for: depth))
                    .offset(offset(for: depth, progress: stackProgress))
                    .rotationEffect(rotation(for: depth))
                    .shadow(color: .black.opacity(shadowOpacity(for: depth)), radius: 30, x: 0, y: 18)
                    .shadow(color: .white.opacity(highlightOpacity(for: depth)), radius: 18, x: 0, y: -6)
                    .zIndex(Double(friends.count - depth))
                    .onTapGesture {
                        toggleFlip(for: friend, depth: depth)
                    }
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
        .onChange(of: selectedIndex) { _, _ in
            flippedFriendID = nil
        }
        .onChange(of: friends.map(\.id)) { _, _ in
            flippedFriendID = nil
        }
        .accessibilityElement(children: .contain)
    }

    private var activeTranslation: CGSize {
        isAnimatingExit ? exitTranslation : dragTranslation
    }

    private var stackProgress: CGFloat {
        max(skipProgress, min(1, abs(activeTranslation.width) / 180))
    }

    private var visibleCards: [Friend] {
        guard !friends.isEmpty else {
            return []
        }

        return friends.indices.map { offset in
            friends[(selectedIndex + offset) % friends.count]
        }
    }

    private func toggleFlip(for friend: Friend, depth: Int) {
        guard depth == 0, !isAnimatingExit else {
            return
        }

        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
            flippedFriendID = flippedFriendID == friend.id ? nil : friend.id
        }
    }

    private func beginSkipAnimation() {
        guard !friends.isEmpty, !isAnimatingExit else {
            return
        }

        isAnimatingExit = true
        flippedFriendID = nil
        dragTranslation = .zero
        exitTranslation = .zero

        withAnimation(.spring(response: 0.18, dampingFraction: 0.58)) {
            skipPopScale = 1.1
            skipProgress = 0.45
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.easeIn(duration: 0.18)) {
                skipPopScale = 0.12
                skipPopOpacity = 0
                skipProgress = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            onSkip()
            skipPopScale = 1
            skipPopOpacity = 1
            skipProgress = 0
            dragTranslation = .zero
            exitTranslation = .zero
            isAnimatingExit = false
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
        flippedFriendID = nil
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

    private func popScale(for depth: Int) -> CGFloat {
        depth == 0 ? skipPopScale : 1
    }

    private func opacity(for depth: Int) -> Double {
        depth == 0 ? skipPopOpacity : 1
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
    let isFlipped: Bool
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            cardBackground
                .overlay(alignment: .topTrailing) {
                    if showsSkipButton && !isFlipped {
                        Button("Skip check-in", action: onSkip)
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .tint(.gray.opacity(0.45))
                            .padding(18)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    frontContent
                        .padding(24)
                }
                .opacity(isFlipped ? 0 : 1)

            cardBackground
                .overlay {
                    backContent
                        .padding(24)
                }
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.62)
        .animation(.spring(response: 0.48, dampingFraction: 0.82), value: isFlipped)
        .frame(maxWidth: .infinity)
        .frame(height: 360)
    }

    private var cardBackground: some View {
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
    }

    private var frontContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(friend.displayName)
                .font(.title2.weight(.semibold))

            Text(lastCheckInText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var backContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(friend.displayName) - \(friend.groupName)")
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    if !cleanCity.isEmpty {
                        Text(cleanCity)
                            .font(.subheadline.italic())
                            .foregroundStyle(.secondary)
                    }
                }

                if !cleanGeneralNotes.isEmpty {
                    Text(cleanGeneralNotes)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()
                    .overlay(.white.opacity(0.25))

                if checkInsWithNotes.isEmpty {
                    Text("No check-in notes yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(checkInsWithNotes) { checkIn in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("notes from \(formattedDate(checkIn.date))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(cleanNote(for: checkIn))
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cleanCity: String {
        friend.city.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanGeneralNotes: String {
        friend.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var checkInsWithNotes: [CheckIn] {
        friend.checkIns
            .filter { !cleanNote(for: $0).isEmpty }
            .sorted { $0.date > $1.date }
    }

    private func cleanNote(for checkIn: CheckIn) -> String {
        checkIn.note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    private var lastCheckInText: String {
        guard let date = friend.latestCompletedCheckInDate else {
            return "No check-ins yet"
        }

        return "Last checked in \(date.formatted(date: .abbreviated, time: .omitted))"
    }
}
private struct CheckInDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let friend: Friend
    var onSave: (() -> Void)? = nil

    @State private var checkInDate = Date()
    @State private var note = ""
    @State private var showingFutureDateConfirmation = false
    @FocusState private var isNoteFocused: Bool

    var body: some View {
        Form {
            Section("Friend") {
                LabeledContent("Name", value: friend.displayName)
                LabeledContent("Last check-in", value: lastCheckInText)
            }
            .onTapGesture {
                isNoteFocused = false
            }

            Section("Check-in date") {
                AccentDatePicker("Date", selection: $checkInDate)
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
                .tint(.secondary)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add", action: confirmSave)
            }
        }
        .sheet(isPresented: $showingFutureDateConfirmation) {
            FutureCheckInConfirmationView(
                date: checkInDate,
                onCancel: {
                    showingFutureDateConfirmation = false
                },
                onAdd: {
                    showingFutureDateConfirmation = false
                    save()
                }
            )
            .presentationDetents([.height(230)])
        }
    }

    private var lastCheckInText: String {
        guard let date = friend.latestCompletedCheckInDate else {
            return "Never"
        }

        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private var isFutureCheckInDate: Bool {
        Calendar.current.startOfDay(for: checkInDate) > Calendar.current.startOfDay(for: .now)
    }

    private func confirmSave() {
        if isFutureCheckInDate {
            showingFutureDateConfirmation = true
        } else {
            save()
        }
    }

    private func save() {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let checkIn = CheckIn(date: checkInDate.withCurrentTime(), note: cleanNote, kind: .checkedIn, friend: friend)
        friend.checkIns.append(checkIn)
        modelContext.insert(checkIn)

        try? modelContext.save()
        NotificationScheduler.scheduleReminder(for: friend)
        onSave?()
        dismiss()
    }
}

private struct FutureCheckInConfirmationView: View {
    let date: Date
    let onCancel: () -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("Record future check-in?")
                    .font(.headline)

                Text("This check-in is dated \(date.formatted(date: .abbreviated, time: .omitted)).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.borderedProminent)
                    .tint(.gray.opacity(0.45))

                Button("Add", action: onAdd)
                    .buttonStyle(.borderedProminent)
                    .tint(.goodFriendsAccent)
            }
            .controlSize(.large)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .preferredColorScheme(.dark)
    }
}

private struct FriendsTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Friend.name) private var friends: [Friend]

    @State private var showingFriendForm = false

    private var groupedFriends: [(name: String, friends: [Friend])] {
        Dictionary(grouping: friends) { $0.groupName.trimmedOrFallback("Friends") }
            .map { ($0.key, $0.value.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }) }
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
            .appNavigationImageHeader("FriendsHeader", accessibilityLabel: "FRiENDS")
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
    @State private var colorPickerButtonFrame: CGRect = .zero

    var body: some View {
        HStack {
            Label {
                Text(name)
            } icon: {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 12, height: 12)
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
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: ColorPickerButtonFramePreferenceKey.self,
                            value: proxy.frame(in: .global)
                        )
                }
            }
            .onPreferenceChange(ColorPickerButtonFramePreferenceKey.self) { frame in
                colorPickerButtonFrame = frame
            }
            .accessibilityLabel("Change \(name) color")
            .popover(isPresented: $showingColorPicker, arrowEdge: colorPickerArrowEdge) {
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

    private var colorPickerArrowEdge: Edge {
        guard colorPickerButtonFrame != .zero else {
            return .top
        }

        let availableBelow = UIScreen.main.bounds.height - colorPickerButtonFrame.maxY
        let availableAbove = colorPickerButtonFrame.minY
        let preferredHeight = GroupColorPickerPopover.preferredHeight

        return availableBelow < preferredHeight && availableAbove > availableBelow ? .bottom : .top
    }
}

private struct ColorPickerButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct GroupColorPickerPopover: View {
    static let maxHeight: CGFloat = 320
    static let preferredHeight: CGFloat = min(maxHeight, CGFloat(GroupColorPalette.sortedOptions.count) * 44 + 20)

    let selectedColorHex: String
    let onSelectColor: (String) -> Void

    var body: some View {
        ScrollView {
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
        }
        .frame(maxHeight: Self.maxHeight)
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
            .appNavigationImageHeader("HistoryHeader", accessibilityLabel: "HiSTORY")
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

private struct StatsTabView: View {
    @Query(sort: \Friend.name) private var friends: [Friend]
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @State private var isDraggingStatsBalloon = false

    private let calendar = Calendar.current

    private var completedCheckIns: [CheckIn] {
        checkIns.filter { $0.kind == .checkedIn }
    }

    private var plannedCheckInsPerMonth: Int {
        let planned = friends.reduce(0.0) { total, friend in
            let threshold = max(friend.thresholdDays, 1)
            return total + 30.4375 / Double(threshold)
        }

        return Int(planned.rounded())
    }

    private var checkInsThisWeek: Int {
        completedCheckIns(in: .weekOfYear)
    }

    private var checkInsThisYear: Int {
        completedCheckIns(in: .year)
    }

    private var allTimeCheckIns: Int {
        completedCheckIns.count
    }

    private var monthlyCounts: [MonthlyCheckInCount] {
        let currentMonth = monthStart(for: .now)

        return (0..<6).reversed().compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: -offset, to: currentMonth),
                  let interval = calendar.dateInterval(of: .month, for: month) else {
                return nil
            }

            let count = completedCheckIns.filter { interval.contains($0.date) }.count
            return MonthlyCheckInCount(month: month, count: count)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    StatsFriendOverviewCard(
                        closeFriendsCount: friends.count,
                        plannedCheckInsPerMonth: plannedCheckInsPerMonth,
                        isDraggingBalloon: $isDraggingStatsBalloon
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Check-in History")
                            .font(.headline)

                        HStack(spacing: 12) {
                            StatsCompactCard(title: "This week", value: "\(checkInsThisWeek)")
                            StatsCompactCard(title: "This year", value: "\(checkInsThisYear)")
                            StatsCompactCard(title: "All-time", value: "\(allTimeCheckIns)")
                        }

                        StatsMonthlyChart(monthlyCounts: monthlyCounts)
                    }
                }
                .padding(20)
            }
            .scrollDisabled(isDraggingStatsBalloon)
            .background(Color(.systemGroupedBackground))
            .appNavigationHeader("Stats")
        }
    }

    private func monthStart(for date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    private func completedCheckIns(in component: Calendar.Component) -> Int {
        guard let interval = calendar.dateInterval(of: component, for: .now) else {
            return 0
        }

        return completedCheckIns.filter { interval.contains($0.date) }.count
    }
}

private struct StatsFriendOverviewCard: View {
    let closeFriendsCount: Int
    let plannedCheckInsPerMonth: Int
    @Binding var isDraggingBalloon: Bool
    @StateObject private var balloonDragState = StatsBalloonDragState()
    @State private var balloonPhysicsScene = StatsBalloonPhysicsScene()

    // Tune these normalized points to move the strings' hand anchors.
    // x and y are measured from the silhouette image's top-left corner, from 0...1.
    private let leftHandAnchor = CGPoint(x: 0.099, y: 0.465)
    private let rightHandAnchor = CGPoint(x: 0.901, y: 0.465)
    private let silhouetteSourceSize = CGSize(width: 853, height: 1844)
    private let balloonScale: CGFloat = 1.09
    private let peopleScale: CGFloat = 0.973
    private let rightBalloonYOffset: CGFloat = 0.104
    private let stringAttachmentY: CGFloat = 0.426

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let baseBalloonSize = CGSize(
                width: min(144, size.width * 0.35),
                height: min(158, size.width * 0.39)
            )
            let balloonSize = CGSize(
                width: baseBalloonSize.width * balloonScale,
                height: baseBalloonSize.height * balloonScale
            )
            let defaultLeftBalloonCenter = CGPoint(x: size.width * 0.27, y: size.height * 0.23)
            let defaultRightBalloonCenter = CGPoint(x: size.width * 0.73, y: size.height * (0.23 + rightBalloonYOffset))
            let leftBalloonCenter = balloonDragState.leftBalloonCenter ?? defaultLeftBalloonCenter
            let rightBalloonCenter = balloonDragState.rightBalloonCenter ?? defaultRightBalloonCenter
            let imageFrameSize = CGSize(
                width: size.width * 1.26 * peopleScale,
                height: size.height * 1.02 * peopleScale
            )
            let imageCenter = CGPoint(x: size.width * 0.5, y: size.height * 0.75)
            let imageRect = renderedImageRect(
                sourceSize: silhouetteSourceSize,
                frameSize: imageFrameSize,
                center: imageCenter
            )
            let leftHandPoint = point(in: imageRect, normalized: leftHandAnchor)
            let rightHandPoint = point(in: imageRect, normalized: rightHandAnchor)

            ZStack {
                SpriteView(scene: balloonPhysicsScene, options: [.allowsTransparency])
                    .frame(width: size.width, height: size.height)
                    .allowsHitTesting(false)

                statsBalloonRope(
                    from: leftHandPoint,
                    to: CGPoint(x: leftBalloonCenter.x, y: leftBalloonCenter.y + balloonSize.height * stringAttachmentY),
                    controlOffset: 12
                )

                statsBalloonRope(
                    from: rightHandPoint,
                    to: CGPoint(x: rightBalloonCenter.x, y: rightBalloonCenter.y + balloonSize.height * stringAttachmentY),
                    controlOffset: -4
                )

                Image("StatsFriendsSilhouette")
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageFrameSize.width, height: imageFrameSize.height)
                    .position(imageCenter)
                    .allowsHitTesting(false)

                StatsBalloonView(
                    value: "\(closeFriendsCount)",
                    title: "Close friends"
                )
                    .frame(width: balloonSize.width, height: balloonSize.height)
                    .position(leftBalloonCenter)

                StatsBalloonView(
                    value: "\(plannedCheckInsPerMonth)",
                    title: "Planned monthly"
                )
                    .frame(width: balloonSize.width, height: balloonSize.height)
                    .position(rightBalloonCenter)

                balloonDragHitArea(
                    side: .left,
                    center: leftBalloonCenter,
                    hitSize: balloonHitSize(for: balloonSize)
                )

                balloonDragHitArea(
                    side: .right,
                    center: rightBalloonCenter,
                    hitSize: balloonHitSize(for: balloonSize)
                )
            }
            .coordinateSpace(name: "statsBalloonCanvas")
            .onAppear {
                configureBalloonDragState(
                    size: size,
                    balloonSize: balloonSize,
                    leftBalloonCenter: defaultLeftBalloonCenter,
                    rightBalloonCenter: defaultRightBalloonCenter
                )
            }
            .onChange(of: size) { _, newSize in
                configureBalloonDragState(
                    size: newSize,
                    balloonSize: balloonSize,
                    leftBalloonCenter: defaultLeftBalloonCenter,
                    rightBalloonCenter: defaultRightBalloonCenter
                )
            }
            .onChange(of: balloonSize) { _, newBalloonSize in
                configureBalloonDragState(
                    size: size,
                    balloonSize: newBalloonSize,
                    leftBalloonCenter: defaultLeftBalloonCenter,
                    rightBalloonCenter: defaultRightBalloonCenter
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 455)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(closeFriendsCount) close friends, \(plannedCheckInsPerMonth) planned check-ins per month")
        .onReceive(balloonDragState.$isDragging.removeDuplicates()) { isDragging in
            isDraggingBalloon = isDragging
        }
    }

    private func configureBalloonDragState(
        size: CGSize,
        balloonSize: CGSize,
        leftBalloonCenter: CGPoint,
        rightBalloonCenter: CGPoint
    ) {
        balloonDragState.configureIfNeeded(
            layoutSize: size,
            balloonSize: balloonSize,
            leftBalloonCenter: leftBalloonCenter,
            rightBalloonCenter: rightBalloonCenter
        )
        balloonPhysicsScene.configure(
            size: size,
            balloonSize: balloonSize,
            leftBalloonCenter: leftBalloonCenter,
            rightBalloonCenter: rightBalloonCenter
        ) { leftCenter, rightCenter in
            balloonDragState.update(leftBalloonCenter: leftCenter, rightBalloonCenter: rightCenter)
        }
    }

    private func renderedImageRect(sourceSize: CGSize, frameSize: CGSize, center: CGPoint) -> CGRect {
        let sourceAspectRatio = sourceSize.width / sourceSize.height
        let frameAspectRatio = frameSize.width / frameSize.height
        let renderedSize: CGSize

        if sourceAspectRatio > frameAspectRatio {
            renderedSize = CGSize(width: frameSize.width, height: frameSize.width / sourceAspectRatio)
        } else {
            renderedSize = CGSize(width: frameSize.height * sourceAspectRatio, height: frameSize.height)
        }

        return CGRect(
            x: center.x - renderedSize.width / 2,
            y: center.y - renderedSize.height / 2,
            width: renderedSize.width,
            height: renderedSize.height
        )
    }

    private func point(in rect: CGRect, normalized point: CGPoint) -> CGPoint {
        CGPoint(
            x: rect.minX + rect.width * point.x,
            y: rect.minY + rect.height * point.y
        )
    }

    private func statsBalloonRope(from start: CGPoint, to end: CGPoint, controlOffset: CGFloat) -> some View {
        StatsBalloonRopeShape(start: start, end: end, controlOffset: controlOffset)
            .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    private func balloonHitSize(for balloonSize: CGSize) -> CGSize {
        CGSize(
            width: balloonSize.width * 1.12,
            height: balloonSize.height * 1.12
        )
    }

    private func balloonDragHitArea(side: StatsBalloonSide, center: CGPoint, hitSize: CGSize) -> some View {
        Rectangle()
            .fill(.clear)
            .contentShape(Rectangle())
            .frame(width: hitSize.width, height: hitSize.height)
            .position(center)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("statsBalloonCanvas"))
                    .onChanged { value in
                        balloonDragState.setDragging(true)
                        balloonPhysicsScene.drag(side, to: value.location)
                    }
                    .onEnded { value in
                        balloonPhysicsScene.endDrag(
                            predictedVelocity: CGVector(
                                dx: value.predictedEndLocation.x - value.location.x,
                                dy: value.predictedEndLocation.y - value.location.y
                            )
                        )
                        balloonDragState.setDragging(false)
                    }
            )
    }
}

private enum StatsBalloonSide {
    case left
    case right
}

private final class StatsBalloonDragState: ObservableObject {
    @Published var leftBalloonCenter: CGPoint?
    @Published var rightBalloonCenter: CGPoint?
    @Published var isDragging = false

    private var layoutSize: CGSize = .zero
    private var balloonSize: CGSize = .zero

    func configureIfNeeded(
        layoutSize: CGSize,
        balloonSize: CGSize,
        leftBalloonCenter: CGPoint,
        rightBalloonCenter: CGPoint
    ) {
        guard self.layoutSize != layoutSize
            || self.balloonSize != balloonSize
            || self.leftBalloonCenter == nil
            || self.rightBalloonCenter == nil else {
            return
        }

        self.layoutSize = layoutSize
        self.balloonSize = balloonSize
        self.leftBalloonCenter = leftBalloonCenter
        self.rightBalloonCenter = rightBalloonCenter
    }

    func update(leftBalloonCenter: CGPoint, rightBalloonCenter: CGPoint) {
        self.leftBalloonCenter = leftBalloonCenter
        self.rightBalloonCenter = rightBalloonCenter
    }

    func setDragging(_ isDragging: Bool) {
        self.isDragging = isDragging
    }
}

private final class StatsBalloonPhysicsScene: SKScene {
    private enum PhysicsCategory {
        static let balloon: UInt32 = 1 << 0
        static let boundary: UInt32 = 1 << 1
    }

    private var leftNode: SKNode?
    private var rightNode: SKNode?
    private var leftHome = CGPoint.zero
    private var rightHome = CGPoint.zero
    private var dragTarget: CGPoint?
    private var activeSide: StatsBalloonSide?
    private var updateCenters: ((CGPoint, CGPoint) -> Void)?
    private var configuredSize: CGSize = .zero
    private var configuredBalloonSize: CGSize = .zero

    override init(size: CGSize = .zero) {
        super.init(size: size)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    override func didMove(to view: SKView) {
        view.preferredFramesPerSecond = 120
    }

    func configure(
        size: CGSize,
        balloonSize: CGSize,
        leftBalloonCenter: CGPoint,
        rightBalloonCenter: CGPoint,
        updateCenters: @escaping (CGPoint, CGPoint) -> Void
    ) {
        self.updateCenters = updateCenters

        guard configuredSize != size
            || configuredBalloonSize != balloonSize
            || leftNode == nil
            || rightNode == nil else {
            return
        }

        configuredSize = size
        configuredBalloonSize = balloonSize
        self.size = size
        leftHome = spritePoint(from: leftBalloonCenter)
        rightHome = spritePoint(from: rightBalloonCenter)
        dragTarget = nil
        activeSide = nil

        removeAllChildren()
        physicsBody = nil

        let radius = balloonSize.width / 2
        leftNode = makeBalloonNode(position: leftHome, radius: radius)
        rightNode = makeBalloonNode(position: rightHome, radius: radius)

        if let leftNode, let rightNode {
            addChild(leftNode)
            addChild(rightNode)
        }
    }

    func drag(_ side: StatsBalloonSide, to swiftUIPoint: CGPoint) {
        activeSide = side
        dragTarget = spritePoint(from: swiftUIPoint)
    }

    func endDrag(predictedVelocity: CGVector = .zero) {
        if let activeNode {
            let impulseScale: CGFloat = 0.018
            activeNode.physicsBody?.applyImpulse(
                CGVector(
                    dx: predictedVelocity.dx * impulseScale,
                    dy: -predictedVelocity.dy * impulseScale
                )
            )
        }

        dragTarget = nil
        activeSide = nil
    }

    override func update(_ currentTime: TimeInterval) {
        guard let leftNode, let rightNode else {
            return
        }

        applyHomeSpring(to: leftNode, home: leftHome, side: .left)
        applyHomeSpring(to: rightNode, home: rightHome, side: .right)

        updateCenters?(
            swiftUIPoint(from: leftNode.position),
            swiftUIPoint(from: rightNode.position)
        )
    }

    private func commonInit() {
        backgroundColor = .clear
        scaleMode = .resizeFill
        physicsWorld.gravity = .zero
        physicsWorld.speed = 1
    }

    private func makeBalloonNode(position: CGPoint, radius: CGFloat) -> SKNode {
        let node = SKNode()
        node.position = position

        let body = SKPhysicsBody(circleOfRadius: radius)
        body.categoryBitMask = PhysicsCategory.balloon
        body.collisionBitMask = PhysicsCategory.balloon
        body.contactTestBitMask = 0
        body.friction = 0
        body.restitution = 0.92
        body.linearDamping = 0.38
        body.angularDamping = 0.4
        body.allowsRotation = false
        body.mass = 0.09
        node.physicsBody = body

        return node
    }

    private func applyHomeSpring(to node: SKNode, home: CGPoint, side: StatsBalloonSide) {
        let target = activeSide == side ? dragTarget ?? home : home
        let stiffness: CGFloat = activeSide == side ? 105 : 5.2
        let damping: CGFloat = activeSide == side ? 2.2 : 1.15
        let dx = target.x - node.position.x
        let dy = target.y - node.position.y
        let velocity = node.physicsBody?.velocity ?? .zero
        let force = CGVector(
            dx: dx * stiffness - velocity.dx * damping,
            dy: dy * stiffness - velocity.dy * damping
        )

        node.physicsBody?.applyForce(force)
    }

    private var activeNode: SKNode? {
        switch activeSide {
        case .left:
            leftNode
        case .right:
            rightNode
        case nil:
            nil
        }
    }

    private func spritePoint(from swiftUIPoint: CGPoint) -> CGPoint {
        CGPoint(x: swiftUIPoint.x, y: size.height - swiftUIPoint.y)
    }

    private func swiftUIPoint(from spritePoint: CGPoint) -> CGPoint {
        CGPoint(x: spritePoint.x, y: size.height - spritePoint.y)
    }
}

private struct StatsBalloonRopeShape: Shape {
    var start: CGPoint
    var end: CGPoint
    var controlOffset: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(
                AnimatablePair(start.x, start.y),
                AnimatablePair(end.x, end.y)
            )
        }
        set {
            start = CGPoint(x: newValue.first.first, y: newValue.first.second)
            end = CGPoint(x: newValue.second.first, y: newValue.second.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let segmentCount = 10
        let delta = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let distance = max(hypot(delta.x, delta.y), 1)
        let normalized = CGPoint(x: delta.x / distance, y: delta.y / distance)
        let perpendicular = CGPoint(x: -normalized.y, y: normalized.x)
        let stretch = min(max(distance / 190, 0), 1.45)
        let slack = max(0, 1.15 - stretch)
        let sag = 8 + slack * 18
        let sidewaysBow = controlOffset * (0.45 + slack * 0.45)

        path.move(to: start)

        for index in 1...segmentCount {
            let t = CGFloat(index) / CGFloat(segmentCount)
            let wave = sin(.pi * t)
            let previousT = CGFloat(index - 1) / CGFloat(segmentCount)
            let previousWave = sin(.pi * previousT)

            let previousPoint = ropePoint(
                t: previousT,
                wave: previousWave,
                delta: delta,
                perpendicular: perpendicular,
                sag: sag,
                sidewaysBow: sidewaysBow
            )
            let currentPoint = ropePoint(
                t: t,
                wave: wave,
                delta: delta,
                perpendicular: perpendicular,
                sag: sag,
                sidewaysBow: sidewaysBow
            )

            path.addQuadCurve(
                to: currentPoint,
                control: CGPoint(
                    x: (previousPoint.x + currentPoint.x) / 2,
                    y: (previousPoint.y + currentPoint.y) / 2
                )
            )
        }

        return path
    }

    private func ropePoint(
        t: CGFloat,
        wave: CGFloat,
        delta: CGPoint,
        perpendicular: CGPoint,
        sag: CGFloat,
        sidewaysBow: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: start.x + delta.x * t + perpendicular.x * sidewaysBow * wave,
            y: start.y + delta.y * t + sag * wave + perpendicular.y * sidewaysBow * wave
        )
    }
}

private struct StatsBalloonView: View {
    let value: String
    let title: String

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let bodyHeight = size.height * 0.91
            let knotSize = CGSize(width: size.width * 0.085, height: size.height * 0.065)

            ZStack {
                StatsBalloonKnotShape()
                    .fill(Color.goodFriendsAccent)
                    .frame(width: knotSize.width, height: knotSize.height)
                    .position(x: size.width / 2, y: size.height * 0.91)

                StatsBalloonKnotShape()
                    .stroke(.white.opacity(0.12), lineWidth: 1)
                    .frame(width: knotSize.width, height: knotSize.height)
                    .position(x: size.width / 2, y: size.height * 0.91)

                StatsBalloonBodyShape()
                    .fill(Color.goodFriendsAccent)
                    .frame(width: size.width, height: bodyHeight)
                    .position(x: size.width / 2, y: bodyHeight / 2)

                StatsBalloonBodyShape()
                    .stroke(.white.opacity(0.12), lineWidth: 1)
                    .frame(width: size.width, height: bodyHeight)
                    .position(x: size.width / 2, y: bodyHeight / 2)

                VStack(spacing: 2) {
                    Text(value)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.48)
                        .monospacedDigit()

                    Text(title)
                        .font(.caption.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(width: size.width, height: size.height * 0.72)
                .position(x: size.width / 2, y: size.height * 0.43)
            }
        }
    }
}

private struct StatsBalloonBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let sideInset: CGFloat = 0
        let shoulderY: CGFloat = 0.468
        let lowerFullness: CGFloat = 1
        let neckWidth: CGFloat = 0.08
        let bottomY: CGFloat = 0.995
        let rightShoulder = CGPoint(
            x: rect.minX + rect.width * (1 - sideInset),
            y: rect.minY + rect.height * shoulderY
        )
        let rightNeck = CGPoint(
            x: rect.midX + rect.width * neckWidth / 2,
            y: rect.minY + rect.height * bottomY
        )
        let leftNeck = CGPoint(
            x: rect.midX - rect.width * neckWidth / 2,
            y: rect.minY + rect.height * bottomY
        )
        let leftShoulder = CGPoint(
            x: rect.minX + rect.width * sideInset,
            y: rect.minY + rect.height * shoulderY
        )

        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: rightShoulder,
            control1: CGPoint(x: rect.minX + rect.width * 0.76, y: rect.minY),
            control2: CGPoint(x: rect.minX + rect.width * 1.02, y: rect.minY + rect.height * 0.17)
        )
        path.addCurve(
            to: rightNeck,
            control1: CGPoint(x: rect.minX + rect.width * lowerFullness, y: rect.minY + rect.height * 0.74),
            control2: CGPoint(x: rect.minX + rect.width * 0.74, y: rect.minY + rect.height * 0.98)
        )
        path.addCurve(
            to: leftNeck,
            control1: CGPoint(x: rect.midX + rect.width * neckWidth * 0.12, y: rect.minY + rect.height),
            control2: CGPoint(x: rect.midX - rect.width * neckWidth * 0.12, y: rect.minY + rect.height)
        )
        path.addCurve(
            to: leftShoulder,
            control1: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.minY + rect.height * 0.98),
            control2: CGPoint(x: rect.minX + rect.width * (1 - lowerFullness), y: rect.minY + rect.height * 0.74)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX - rect.width * 0.02, y: rect.minY + rect.height * 0.17),
            control2: CGPoint(x: rect.minX + rect.width * 0.24, y: rect.minY)
        )

        return path
    }
}

private struct StatsBalloonKnotShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bottomCornerRadius = rect.width * 0.12
        let topPoint = CGPoint(x: rect.midX, y: rect.minY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY - bottomCornerRadius)
        let rightBase = CGPoint(x: rect.maxX - bottomCornerRadius, y: rect.maxY)
        let leftBase = CGPoint(x: rect.minX + bottomCornerRadius, y: rect.maxY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY - bottomCornerRadius)

        path.move(to: topPoint)
        path.addLine(to: bottomRight)
        path.addQuadCurve(to: rightBase, control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: leftBase)
        path.addQuadCurve(to: bottomLeft, control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: topPoint)

        return path
    }
}

private struct StatsCompactCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .monospacedDigit()

            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct StatsMonthlyChart: View {
    let monthlyCounts: [MonthlyCheckInCount]

    private var maxCount: Int {
        max(monthlyCounts.map(\.count).max() ?? 0, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Monthly check-ins", systemImage: "chart.bar.xaxis")
                    .font(.headline)

                Spacer()
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(monthlyCounts) { month in
                    VStack(spacing: 8) {
                        Text("\(month.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(height: 14)

                        GeometryReader { proxy in
                            VStack {
                                Spacer(minLength: 0)

                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(barColor(for: month))
                                    .frame(height: barHeight(for: month, availableHeight: proxy.size.height))
                            }
                        }
                        .frame(height: 150)

                        Text(month.label)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(month.accessibilityLabel), \(month.count) check-ins")
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func barHeight(for month: MonthlyCheckInCount, availableHeight: CGFloat) -> CGFloat {
        guard month.count > 0 else {
            return 4
        }

        return max(10, availableHeight * CGFloat(month.count) / CGFloat(maxCount))
    }

    private func barColor(for month: MonthlyCheckInCount) -> Color {
        month.isCurrentMonth ? .goodFriendsAccent : .secondary.opacity(0.55)
    }
}

private struct MonthlyCheckInCount: Identifiable {
    let month: Date
    let count: Int

    var id: Date { month }

    var label: String {
        month.formatted(.dateTime.month(.abbreviated))
    }

    var accessibilityLabel: String {
        month.formatted(.dateTime.month(.wide).year())
    }

    var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: .now, toGranularity: .month)
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

                LabeledContent("Friend", value: checkIn.friend?.displayName ?? "Deleted Friend")
                AccentDatePicker("Date", selection: checkInDate)
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
                Text("\(checkIn.kind.title) - \(checkIn.friend?.displayName ?? "Deleted Friend")")
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
                Text(friend.displayName)
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
        if let latest = friend.latestCompletedCheckInDate {
            return "Last check-in \(latest.formatted(date: .abbreviated, time: .omitted))"
        }
        return "No check-ins yet"
    }
}

private struct AccentDatePicker: View {
    let title: LocalizedStringKey
    @Binding var selection: Date

    init(_ title: LocalizedStringKey, selection: Binding<Date>) {
        self.title = title
        self._selection = selection
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .lineLimit(1)
                .layoutPriority(1)

            ZStack(alignment: .trailing) {
                DatePicker("", selection: $selection, displayedComponents: .date)
                    .labelsHidden()
                    .tint(.goodFriendsAccent)
                    .opacity(0.02)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        Text(selection.formatted(date: .abbreviated, time: .omitted))
                        Image(systemName: "calendar")
                            .imageScale(.small)
                    }
                    .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(selection.formatted(.dateTime.month().day().year(.twoDigits)))
                        Image(systemName: "calendar")
                            .imageScale(.small)
                    }
                    .lineLimit(1)
                }
                .foregroundStyle(Color.goodFriendsAccent)
                .allowsHitTesting(false)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .contentShape(Rectangle())
        }
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

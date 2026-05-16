import SwiftData
import SwiftUI

@main
struct GoodFriendsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Friend.self, CheckIn.self])
    }
}

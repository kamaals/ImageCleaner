import SwiftUI
import SwiftData

@main
struct ImageCleanerApp: App {
    @State private var appTheme = AppTheme()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appTheme)
        }
        .modelContainer(for: [CleaningSession.self])
    }
}

import SwiftUI
import SwiftData

@main
struct ImageCleanerApp: App {
    @State private var appTheme = AppTheme()

    var body: some Scene {
        WindowGroup {
            // TEMP: preview the icon draw animation for visual comparison.
            AppIconDrawAnimation()
                .frame(width: 320, height: 320)
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .environment(appTheme)
        }
        .modelContainer(for: [CleaningSession.self])
    }
}

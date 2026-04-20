import SwiftUI
import SwiftData

@main
struct ImageCleanerApp: App {
    @State private var appTheme = AppTheme()
    @State private var scanStore: ScanStore

    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            ScannedAsset.self,
            DuplicateGroupRecord.self,
            ScanSession.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // In release, a schema migration failure here is recoverable by
            // nuking the store — but for the prototype we fail loudly.
            fatalError("Could not initialize ModelContainer: \(error)")
        }
        self.modelContainer = container
        self._scanStore = State(wrappedValue: ScanStore(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environment(appTheme)
                .environment(scanStore)
        }
        .modelContainer(modelContainer)
    }
}

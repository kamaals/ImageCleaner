import SwiftUI
import SwiftData
import RevenueCat

@main
struct ImageCleanerApp: App {
    @State private var appTheme = AppTheme()
    @State private var scanStore: ScanStore
    @State private var entitlements: EntitlementStore

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

        // Configure RevenueCat BEFORE creating EntitlementStore — the store
        // reads `Purchases.shared.cachedCustomerInfo` synchronously on init.
        //
        // Per-config API key: RevenueCat fatal-errors on a `test_` key in a
        // Release build (that guardrail blocks a Test Store key from reaching
        // production). Debug uses the Test Store key for paywall dev; the
        // Release placeholder below lets us run Release for *non-paywall*
        // testing — e.g. confirming the SCAN morph is smooth. Swap your real
        // `appl_…` key from the RevenueCat dashboard in before shipping (and
        // ideally lift these into an .xcconfig per-build-config).
        #if DEBUG
        Purchases.configure(withAPIKey: "test_NFPtZcrFSbdeamXPngSWfgdgYbS")
        #else
        Purchases.configure(withAPIKey: "appl_PLACEHOLDER_FOR_RELEASE_TESTING_DO_NOT_SHIP")
        #endif
        self._entitlements = State(wrappedValue: EntitlementStore())
    }

    var body: some Scene {
        WindowGroup {
            SplashView()
                .modifier(GlobalPaywallSheetModifier())
                .environment(appTheme)
                .environment(scanStore)
                .environment(entitlements)
        }
        .modelContainer(modelContainer)
    }
}

/// Hosts the single app-wide paywall sheet. Any view can summon it via
/// `entitlements.requireEntitlement(then:)`; this modifier listens to
/// `pendingPaywallAction` and presents `PaywallView` accordingly. Centralising
/// the sheet means delete-site call sites stay one-liner clean.
private struct GlobalPaywallSheetModifier: ViewModifier {
    @Environment(EntitlementStore.self) private var entitlements

    func body(content: Content) -> some View {
        @Bindable var entitlements = entitlements
        return content.sheet(item: $entitlements.pendingPaywallAction) { _ in
            AppPaywallView()
                .environment(entitlements)
        }
    }
}

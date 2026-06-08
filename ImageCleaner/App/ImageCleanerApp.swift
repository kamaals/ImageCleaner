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
        // Key comes from Config.xcconfig (gitignored) → Info.plist's
        // `RevenueCatAPIKey`. Debug build resolves to a `test_…` key
        // (RevenueCat's Test Store, synthetic products). Release resolves to
        // the production `appl_…` key. See Config.xcconfig.example for setup.
        Purchases.configure(withAPIKey: Self.revenueCatAPIKey())
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

    /// Reads `RevenueCatAPIKey` from the merged Info.plist (sourced from
    /// `Config.xcconfig` at build time). In DEBUG we crash on a missing /
    /// placeholder key because there's no scenario where launching a Debug
    /// build with an unwired xcconfig is intentional — better to surface it
    /// loudly here than spend half an hour wondering why the paywall is
    /// blank. In RELEASE we return an empty string and let RevenueCat fail
    /// to initialise; the rest of the app still boots, and `AppPaywallView`
    /// will surface the "Couldn't load subscription options" failure path
    /// instead of crashing on a real user.
    private static func revenueCatAPIKey() -> String {
        let key = (Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String) ?? ""
        #if DEBUG
        if key.isEmpty || key.hasPrefix("appl_PASTE") || key.hasPrefix("test_REPLACE") {
            fatalError("""
                Missing RevenueCatAPIKey. Make sure Config.xcconfig exists \
                (copy from Config.xcconfig.example) and is wired in Xcode: \
                Project → Info → Configurations → set Debug + Release to Config.
                """)
        }
        #endif
        return key
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

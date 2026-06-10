import SwiftUI

struct ContentView: View {
    @Environment(AppTheme.self) private var theme
    @State private var viewModel: HomeViewModel
    var heroNamespace: Namespace.ID?
    private let startWithResults: Bool

    /// - Parameter startWithResults: when `true` a completed scan is already
    ///   persisted, so we seed the navigation path with `.results` and the app
    ///   opens straight into the saved results — no re-scan. The `ResultsView`
    ///   is on the stack from the first render, so it appears without a push
    ///   animation; tapping Back reveals the (settled) SCAN home screen.
    init(heroNamespace: Namespace.ID? = nil, startWithResults: Bool = false) {
        self.heroNamespace = heroNamespace
        self.startWithResults = startWithResults
        let homeVM = HomeViewModel()
        if startWithResults {
            homeVM.navigationPath.append(HomeDestination.results)
        }
        _viewModel = State(initialValue: homeVM)
    }

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            ScanTransitionView(
                homeVM: viewModel,
                heroNamespace: heroNamespace,
                startWithResults: startWithResults
            )
                .navigationDestination(for: HomeDestination.self) { destination in
                    switch destination {
                    case .scan:
                        ScanView()
                    case .results:
                        ResultsView()
                    case .duplicates:
                        DuplicatesDetailView(kind: .exact)
                    case .similars:
                        DuplicatesDetailView(kind: .similar)
                    case .screenshots:
                        ScreenshotsDetailView()
                    case .blankPhotos:
                        BlankPhotosDetailView()
                    case .settings:
                        SettingsView()
                    }
                }
        }
        .preferredColorScheme(theme.resolvedColorScheme)
    }
}

#Preview("Content") {
    ContentView()
        .environment(AppTheme())
}

#Preview("Icon draw animation") {
    AppIconDrawAnimation()
        .frame(width: 280, height: 280)
        .padding(40)
}

#Preview("Splash View") {
    SplashView()
        .environment(AppTheme())
}

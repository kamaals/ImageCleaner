import SwiftUI

struct ContentView: View {
    @Environment(AppTheme.self) private var theme
    @State private var viewModel = HomeViewModel()
    var heroNamespace: Namespace.ID?

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            ScanTransitionView(homeVM: viewModel, heroNamespace: heroNamespace)
                .navigationDestination(for: HomeDestination.self) { destination in
                    switch destination {
                    case .scan:
                        ScanView()
                    case .results:
                        ResultsView()
                    case .duplicates:
                        DuplicatesDetailView()
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

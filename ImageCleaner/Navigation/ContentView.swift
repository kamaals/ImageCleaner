import SwiftUI

struct ContentView: View {
    @Environment(AppTheme.self) private var theme
    @State private var viewModel = HomeViewModel()
    var heroNamespace: Namespace.ID?

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            ScanTransitionView(homeVM: viewModel, heroNamespace: heroNamespace)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(value: HomeDestination.settings) {
                            Label("Settings", systemImage: "gearshape")
                        }
                    }
                }
                .navigationDestination(for: HomeDestination.self) { destination in
                    switch destination {
                    case .scan:
                        ScanView()
                    case .results:
                        ResultsView()
                    case .settings:
                        SettingsView()
                    }
                }
        }
        .preferredColorScheme(theme.resolvedColorScheme)
    }
}

#Preview {
    ContentView()
        .environment(AppTheme())
}

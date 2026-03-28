import SwiftUI

struct ContentView: View {
    @Environment(AppTheme.self) private var theme
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            ScanTransitionView(homeVM: viewModel)
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

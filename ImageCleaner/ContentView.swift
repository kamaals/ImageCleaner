import SwiftUI

struct ContentView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            VStack(alignment: .leading, spacing: 0) {
                AppIconView(
                    foreground: colorScheme == .dark ? .white : .black,
                    invertedForeground: colorScheme == .dark ? .black : .white
                )
                .frame(width: 100, height: 100)
                .padding(.top, 40)

                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        viewModel.navigateToScan()
                    } label: {
                        Text("SCAN")
                            .font(AppFont.largeTitle)
                            .tracking(2)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }
                    .accessibilityLabel("Start scan")

                    Button {
                        viewModel.navigateToResults()
                    } label: {
                        Text("View Last Results")
                            .font(AppFont.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("View last scan results")

                    Toggle(isOn: $viewModel.forceRescan) {
                        Text("Force Re-Scan")
                            .font(AppFont.subheadline)
                    }
                    .toggleStyle(CheckboxToggleStyle())
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
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

import SwiftUI

struct ContentView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var forceRescan = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Logo
                AppIconView(
                    foreground: colorScheme == .dark ? .white : .black,
                    invertedForeground: colorScheme == .dark ? .black : .white
                )
                .frame(width: 100, height: 100)
                .padding(.top, 40)

                Spacer()

                // SCAN button
                VStack(alignment: .leading, spacing: 12) {
                    NavigationLink {
                        ScanView()
                    } label: {
                        Text("SCAN")
                            .font(AppFont.largeTitle)
                            .tracking(2)
                            .foregroundStyle(colorScheme == .dark ? .white : .black)
                    }

                    NavigationLink {
                        ResultsView()
                    } label: {
                        Text("View Last Results")
                            .font(AppFont.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Toggle(isOn: $forceRescan) {
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
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
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

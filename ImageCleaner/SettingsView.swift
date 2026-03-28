import SwiftUI

struct SettingsView: View {
    @Environment(AppTheme.self) private var theme

    var body: some View {
        @Bindable var theme = theme

        Form {
            Section {
                Picker("Appearance", selection: $theme.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Appearance")
                    .font(AppFont.caption)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppTheme())
}

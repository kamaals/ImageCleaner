import SwiftUI

struct ContentView: View {
    @Environment(AppTheme.self) private var theme

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Text("Image Cleaner")
                    .font(AppFont.title)

                Text("Clean up your photo library")
                    .font(AppFont.body)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .frame(maxWidth: .infinity)
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

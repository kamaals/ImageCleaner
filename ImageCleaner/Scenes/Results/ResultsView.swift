import SwiftUI

struct ResultsView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var foreground: Color { colorScheme == .dark ? .white : .black }
    private var background: Color { colorScheme == .dark ? .black : .white }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Reclaimable Space header
            HStack(alignment: .center, spacing: 4) {
                ResizeIcon(
                    foreground: foreground,
                    invertedForeground: background
                )
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 0) {
                    Text("RECLAIMABLE SPACE")
                        .font(AppFont.jost(size: 28, weight: 700))
                        .foregroundStyle(foreground)

                    Text("87 items found")
                        .font(AppFont.jost(size: 16, weight: 400))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.top, 24)
            HStack {
                Spacer().frame(maxWidth:4)
                Text("376.4 MB")
                    .font(AppFont.jost(size: 48, weight: 200))
                    .foregroundStyle(foreground)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ResultsView()
            .environment(AppTheme())
    }
}
